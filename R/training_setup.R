setup_training <- function(d, outcome, model_class, models, metric, positive_class) {

  # Get recipe and remove columns to be ignored in training
  recipe <- attr(d, "recipe")
  if (!is.null(recipe)) {
    outcome_chr <- rlang::quo_name(outcome)
    if (outcome_chr %in% attr(recipe, "ignored_columns"))
      stop("You specified ", outcome_chr, " as your outcome variable, but ",
           "the recipe you used to prep your data says to ignore it. ",
           "Did you forget to specify `outcome = ` in prep_data?")
    d <- remove_ignored(d, recipe)
  }

  # Check outcome provided, agrees with outcome in prep_data, present in d
  outcome <- check_outcome(outcome, names(d), recipe)
  outcome_chr <- rlang::quo_name(outcome)

  # tibbles upset some algorithms, so make it a data frame
  d <- as.data.frame(d)
  # kknn can choke on characters so convert all character variables to factors.
  d <- dplyr::mutate_if(d, is.character, as.factor)

  if (missing(models)) {
    models <- get_supported_models()
  } else {
    # Make `models` case insensitive
    models <- tolower(models)
  }

  # Make sure outcome's class works with model_class, or infer it
  model_class <- set_model_class(model_class, class(dplyr::pull(d, !!outcome)), outcome_chr)

  # Some algorithms need the response to be factor instead of char or lgl
  # Get rid of unused levels if they're present
  if (model_class == "classification") {
    d <- dplyr::mutate(d,
                       !!outcome_chr := as.factor(!!outcome),
                       !!outcome_chr := droplevels(!!outcome))
    # Set outcome positive class
    d[[outcome_chr]] <- set_outcome_class(d[[outcome_chr]], positive_class)
  }

  # Choose metric if not provided
  if (missing(metric))
    metric <- set_default_metric(model_class)

  # Make sure models are supported
  models <- setup_models(models)

  return(list(d = d, outcome = outcome, model_class = model_class,
              models = models, metric = metric, recipe = recipe))
}

check_outcome <- function(outcome, d_names, recipe) {
  if (rlang::quo_is_missing(outcome))
    stop("You must provide an outcome variable to tune_models.")
  outcome_chr <- rlang::quo_name(outcome)
  if (!outcome_chr %in% d_names)
    stop(outcome_chr, " isn't a column in d.")
  if (!is.null(recipe)) {
    prep_outcome <- recipe$var_info$variable[recipe$var_info$role == "outcome"]
    if (length(prep_outcome) && prep_outcome != outcome_chr)
      stop("outcome in prep_data (", prep_outcome, ") and outcome in tune models (",
           outcome_chr, ") are different. They need to be the same.")
  }
  return(outcome)
}

set_outcome_class <- function(vec, positive_class) {
  if (missing(positive_class)) {
    positive_class <-
      if ("Y" %in% levels(vec)) {
        "Y"
      } else if ("yes" %in% levels(vec)) {
        "yes"
      } else {
        levels(vec)[1]
      }
  }
  if (!positive_class %in% levels(vec))
    stop("positive_class, ", positive_class, ", not found in the outcome column. ",
         "Outcome has values ", paste(levels(vec), collapse = " and ") )
  vec <- stats::relevel(vec, positive_class)
  return(vec)
}

remove_ignored <- function(d, recipe) {
  # Pull columns ignored in prep_data out of d
  ignored <- attr(recipe, "ignored_columns")
  # Only ignored columns that are present now
  ignored <- ignored[ignored %in% names(d)]
  if (!is.null(ignored) && length(ignored)) {
    d <- dplyr::select(d, -dplyr::one_of(ignored))
    message("Variable(s) ignored in prep_data won't be used to tune models: ",
            paste(ignored, collapse = ", "))
  }
  return(d)
}

set_model_class <- function(model_class, outcome_class, outcome_chr) {
  looks_categorical <- outcome_class %in% c("character", "factor")
  looks_numeric <- outcome_class %in% c("integer", "numeric")
  if (!looks_categorical && !looks_numeric) {
    # outcome is weird class such as list
    stop(outcome_chr, " is ", outcome_class,
         ", and tune_models doesn't know what to do with that.")
  } else if (missing(model_class)) {
    # Need to infer model_class
    if (looks_categorical) {
      mes <- paste0(outcome_chr, " looks categorical, so training classification algorithms.")
      model_class <- "classification"
    } else {
      mes <- paste0(outcome_chr, " looks numeric, so training regression algorithms.")
      model_class <- "regression"
      # User provided model_class, so check it
    }
    message(mes)
  } else {
    # Check user-provided model_class
    supported_classes <- get_supported_model_classes()
    if (!model_class %in% supported_classes)
      stop("Supported model classes are: ",
           paste(supported_classes, collapse = ", "),
           ". You supplied this unsupported class: ", model_class)
    if (looks_categorical && model_class == "regression") {
      stop(outcome_chr, " looks categorical but you're trying to train a regression model.")
    } else if (looks_numeric && model_class == "classification") {
      stop(outcome_chr, " looks numeric but you're trying to train a classification ",
           "model. If that's what you want convert it explicitly with as.factor().")
    }
  }
  return(model_class)
}


setup_models <- function(models) {
  available <- get_supported_models()
  unsupported <- models[!models %in% available]
  if (length(unsupported))
    stop("Currently supported algorithms are: ",
         paste(available, collapse = ", "),
         ". You supplied these unsupported algorithms: ",
         paste(unsupported, collapse = ", "))
  # We use kknn and ranger, but user input is "knn" and "rf"
  models <- translate_model_names(models)
  return(models)
}

set_default_metric <- function(model_class) {
  if (model_class == "regression") {
    return("RMSE")
  } else if (model_class == "classification") {
    return("ROC")
  } else {
    stop("Don't have default metric for model class", model_class)
  }
}

setup_train_control <- function(tune_method, model_class, metric, n_folds) {
  if (tune_method == "random") {
    train_control <- caret::trainControl(method = "cv",
                                        number = n_folds,
                                        search = "random",
                                        savePredictions = "final")
  } else if (tune_method == "none") {
    # Use grid CV if not tuning (e.g. via flash_models)
    train_control <- caret::trainControl(method = "cv",
                                         number = n_folds,
                                         search = "grid",
                                         savePredictions = "final")
  } else {
    stop("Currently tune_method = \"random\" is the only supported method",
         " but you supplied tune_method = \"", tune_method, "\"")
  }
  # trainControl defaults are good for regression. Change for classification
  if (model_class == "classification") {
    if (metric == "PR") {
      train_control$summaryFunction <- caret::prSummary
    } else {
      train_control$summaryFunction <- caret::twoClassSummary
    }
    train_control$classProbs <- TRUE
  }
  return(train_control)
}
