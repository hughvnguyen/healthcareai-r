#' Machine learning made easy
#'
#' @description Prepare data and train machine learning models.
#'
#' @param d A data frame
#' @param ... Columns to be ignored in model training, e.g. ID columns,
#'   unquoted.
#' @param outcome Name of the target column, i.e. what you want to predict.
#'   Unquoted. Must be named, i.e. you must specify \code{outcome = }
#' @param models Models to be trained, k-nearest neighbors and random forest by
#'   default. See \code{\link{supported_models}} for details.
#' @param tune If TRUE (default) models will be tuned via
#'   \code{\link{tune_models}}. If FALSE, models will be trained via
#'   \code{\link{flash_models}} which is substantially faster but produces
#'   less-predictively powerful models.
#' @param positive_class For classification only, which outcome level is the
#'   "yes" case, i.e. should be associated with high probabilities? Defaults to
#'   "Y" or "yes" if present, otherwise is the first level of the outcome
#'   variable (first alphabetically if the training data outcome was not already
#'   a factor).
#' @param n_folds How many folds to use to assess out-of-fold accuracy? Default
#'   = 5. Models are evaluated on out-of-fold predictions whether tune is TRUE
#'   or FALSE.
#' @param tune_depth How many hyperparameter combinations to try? Defualt = 10.
#'   Ignored if tune is FALSE.
#' @param impute Logical, if TRUE (default) missing values will be filled by
#'   \code{\link{hcai_impute}}
#'
#' @return model_list object ready to make predictions via
#'   \code{\link{predict.model_list}}
#' @export
#'
#' @details This is a high-level wrapper function. For finer control of data
#'   cleaning and preparation use \code{\link{prep_data}} or the functions it
#'   wraps. For finer control of model tuning use \code{\link{tune_models}}.
#'
#' @examples
#' # Split the data into training and test sets, using just 100 rows for speed
#' d <- split_train_test(d = pima_diabetes[1:100, ],
#'                       outcome = diabetes,
#'                       percent_train = .9)
#'
#' ### Classification ###
#'
#' # Clean and prep the training data, specifying that patient_id is an ID column,
#' # and tune algorithms over hyperparameter values to predict diabetes
#' diabetes_models <- machine_learn(d$train, patient_id, outcome = diabetes)
#'
#' # Inspect model specification and performance
#' diabetes_models
#'
#' # Make predictions (predicted probability of diabetes) on test data
#' predict(diabetes_models, d$test)
#'
#' ### Regression ###
#'
#' # If the outcome variable is numeric, regression models will be trained
#' age_model <- machine_learn(d$train, patient_id, outcome = age)
#'
#' # If new data isn't specifed, get predictions on training data
#' predict(age_model)
#'
#' ### Faster model training without tuning hyperparameters ###
#'
#' # Train models at set hyperparameter values by setting tune to FALSE. This is
#' # faster (especially on larger datasets), but produces models with less
#' # predictive accuracy.
#' machine_learn(d$train, patient_id, outcome = diabetes, tune = FALSE)
machine_learn <- function(d, ..., outcome, models, tune = TRUE, positive_class,
                          n_folds = 5, tune_depth = 10, impute = TRUE) {

  if (!is.data.frame(d))
    stop("\"d\" must be a data frame.")

  dots <- rlang::quos(...)
  ignored <- map_chr(dots, rlang::quo_name)
  if (length(ignored)) {
    not_there <- setdiff(ignored, names(d))
    if (length(not_there))
      stop("The following variable(s) were passed to the ... argument of machine_learn",
           " but are not the names of columns in the data frame: ",
           paste(not_there, collapse = ", "))
  }

  outcome <- rlang::enquo(outcome)
  if (rlang::quo_is_missing(outcome)) {
    mes <- "You must provide an outcome variable to machine_learn."
    if (length(ignored))
      mes <- paste(mes, "Did you forget to specify `outcome = `?")
    stop(mes)
  }
  outcome_chr <- rlang::quo_name(outcome)
  if (!outcome_chr %in% names(d))
    stop("You passed ", outcome_chr, " to the outcome argument of machine_learn,",
         "but that isn't a column in d.")

  if (missing(models))
    models <- get_supported_models()

  pd <- prep_data(d, !!!dots, outcome = !!outcome, impute = impute)
  m <-
    if (tune) {
      tune_models(pd, outcome = !!outcome, models = models,
                  positive_class = positive_class,
                  n_folds = n_folds, tune_depth = tune_depth)
    } else {
      flash_models(pd, outcome = !!outcome, models = models,
                   positive_class = positive_class, n_folds = n_folds)
    }
  return(m)
}
