context("Testing prep_data")

# Setup ------------------------------------------------------------------------
# set seed for reproducibility
set.seed(7)
# build data set to predict whether or not animal_id is a is_ween
n <- 300
df <- data.frame(
  song_id = 1:n,
  length = rnorm(n, mean = 4, sd = 1),
  weirdness = rnorm(n, mean = 4, sd = 2),
  genre = sample(c("Rock", "Jazz", "Country"), size = n, replace = T),
  reaction = sample(c("Love", "Huh", "Dislike", "Mixed"),
                    size = n, replace = T),
  guitar_flag = sample(c(0, 1), size = n, replace = T),
  drum_flag = sample(c(0, 1, NA), size = n, replace = T,
                     prob = c(0.45, 0.45, 0.1)),
  date_col = lubridate::ymd("2002-03-04") + lubridate::days(sample(1000, n)),
  posixct_col = lubridate::ymd("2004-03-04") + lubridate::days(sample(1000, n)),
  col_DTS = lubridate::ymd("2006-03-04") + lubridate::days(sample(1000, n)),
  missing82 = sample(1:10, n, replace = TRUE),
  missing64 = sample(100:300, n, replace = TRUE),
  state = sample(c("NY", "MA", "CT", "CA", "VT", "NH"), size = n, replace = T,
                 prob = c(0.18, 0.1, 0.1, 0.6, 0.01, 0.01))
)

# give is_ween likeliness score
df["is_ween"] <- df["length"] - 1 * df["weirdness"] + 2
df$is_ween[df["genre"] == "Rock"]  <-
  df$is_ween[df["genre"] == "Rock"] + 2
df$is_ween[df["genre"] == "Jazz"]  <-
  df$is_ween[df["genre"] == "Jazz"] - 1
df$is_ween[df["genre"] == "Country"]  <-
  df$is_ween[df["genre"] == "Country"] - 1
df$is_ween[df["reaction"] == "Huh"] <-
  df$is_ween[df["reaction"] == "Huh"] + 1
df$is_ween[df["reaction"] == "Love"] <-
  df$is_ween[df["reaction"] == "Love"] + 2
df$is_ween[df["reaction"] == "Mixed"] <-
  df$is_ween[df["reaction"] == "Mixed"] - 1
df$is_ween[df["reaction"] == "Dislike"] <-
  df$is_ween[df["reaction"] == "Dislike"] - 4


# Add noise
df$is_ween <- df$is_ween + rnorm(n, mean = 0, sd = 1.25)
df$is_ween <- ifelse(df$is_ween > 0, "Y", "N")

# Add missing data
df$reaction[sample(1:n, 32, replace = FALSE)] <- NA
df$length[sample(1:n, 51, replace = FALSE)] <- NA
df$genre[sample(1:n, 125, replace = FALSE)] <- NA
df$weirdness[sample(1:n, 9, replace = FALSE)] <- NA

train_index <- caret::createDataPartition(
  df$is_ween,
  p = 0.8,
  times = 1,
  list = TRUE)

d_train <- df[train_index$Resample1, ]
d_test <- df[-train_index$Resample1, ]

d_train$length[1] <- d_test$length[1] <- NA
d_train$reaction[2] <- d_test$reaction[2] <- NA
d_train$weirdness[3] <-  d_test$weirdness[3] <- NA
d_train$genre[3] <- d_test$genre[3] <- NA

d_prep <- prep_data(d = d_train, outcome = is_ween, song_id)
d_reprep <- prep_data(d_test, outcome = is_ween, song_id,
                      recipe = attr(d_prep, "recipe"))
d_reprep2 <- prep_data(d_test, outcome = is_ween, song_id,
                       recipe = d_prep)

# Tests ------------------------------------------------------------------------
test_that("Bad data throws an error", {
  expect_error(prep_data(), regexp = "missing")
  expect_error(prep_data(d = "yeah hi!"), regexp = "data frame")
})

test_that("Bad outcome columns throws an error", {
  expect_error(prep_data(d = d_train, outcome = cowbell),
               regexp = "not found in d")
  d_train$is_ween[1:5] <- NA
  expect_error(prep_data(d = d_train, outcome = is_ween),
               regexp = "NA values")
})

test_that("Bad ignored columns throws a warning", {
  expect_warning(prep_data(d = d_train, cowbell),
                 regexp = "not found in d")
  expect_warning(prep_data(d = d_train, cowbell, spoons),
                 regexp = "not found in d")
})

test_that("prep_data works with just param d", {
  d_clean <- prep_data(d = d_train, make_dummies = FALSE)
  expect_equal(unique(d_clean$weirdness[is.na(d_train$weirdness)]),
               mean(d_train$weirdness, na.rm = TRUE))
  expect_true(all.equal(droplevels(d_clean$genre[!is.na(d_train$genre)]),
                        d_train$genre[!is.na(d_train$genre)]))
  expect_true(all(d_clean$genre[is.na(d_train$genre)] == "missing"))
})

test_that("prep_data works with defaults and no ignore columns", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, make_dummies = FALSE)
  expect_equal(unique(d_clean$weirdness[is.na(d_train$weirdness)]),
               mean(d_train$weirdness, na.rm = TRUE))
  expect_true(all.equal(droplevels(d_clean$genre[!is.na(d_train$genre)]),
                        d_train$genre[!is.na(d_train$genre)]))
  expect_true(all(d_clean$genre[is.na(d_train$genre)] == "missing"))
})

test_that("prep_data works with defaults and one ignore column", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       make_dummies = FALSE)
  expect_equal(unique(d_clean$weirdness[is.na(d_train$weirdness)]),
               mean(d_train$weirdness, na.rm = TRUE))
  expect_true(all.equal(droplevels(d_clean$genre[!is.na(d_train$genre)]),
                        d_train$genre[!is.na(d_train$genre)]))
  expect_true(all(d_clean$genre[is.na(d_train$genre)] == "missing"))
})

test_that("prep_data works with defaults and two ignore columns", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id, state
                       , make_dummies = FALSE)
  expect_equal(unique(d_clean$weirdness[is.na(d_train$weirdness)]),
               mean(d_train$weirdness, na.rm = TRUE))
  expect_true(all.equal(droplevels(d_clean$genre[!is.na(d_train$genre)]),
                        d_train$genre[!is.na(d_train$genre)]))
  expect_true(all(d_clean$genre[is.na(d_train$genre)] == "missing"))
})

test_that("0/1 outcome is converted to N/Y", {
  d_train <- dplyr::mutate(d_train, is_ween = ifelse(is_ween == "Y", 1, 0))
  d_clean <- prep_data(d = d_train, outcome = is_ween)
  expect_s3_class(d_clean$is_ween, "factor")
  expect_true(all.equal(which(d_train$is_ween == 1),
                        which(d_clean$is_ween == "Y")))
  expect_true(all.equal(sort(levels(d_clean$is_ween)), c("N", "Y")))
})

test_that("date columns are found and converted", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       make_dummies = FALSE)
  expect_true(is.factor(d_clean$date_col_dow))
  expect_true(is.factor(d_clean$posixct_col_month))
  expect_true(is.numeric(d_clean$col_DTS_year))
  expect_true(all(c("Jan", "Mar") %in% d_clean$date_col_month))
  expect_true(all(2004:2006 %in% d_clean$posixct_col_year))
  expect_true(all(c("Sun", "Mon", "Tue") %in% d_clean$col_DTS_dow))
})

test_that("date columns are found, converted, and dummified", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id)
  # Should find 11 month names in names of prepped data as all but one get dummied
  expect_equal(sum(purrr::map_lgl(month.abb, ~ any(grepl(.x, names(d_clean))))), 11)
  expect_true("date_col_dow_Thu" %in% names(d_clean))
  expect_equal(sort(unique(d_clean$col_DTS_month_Sep)), c(0, 1))
  expect_true(all(2004:2006 %in% d_clean$posixct_col_year))
})

test_that("convert_dates works when non default", {
  dd <- prep_data(d_train, convert_dates = "quarter")
  expect_true("date_col_quarter" %in% names(dd))
  expect_false("date_col_dow" %in% names(dd))
  dd <- prep_data(d_train, convert_dates = c("doy", "quarter"))
  expect_true(all(c("date_col_doy", "date_col_quarter") %in% names(dd)))
})

test_that("convert_dates removes date columns when false", {
  dd <- prep_data(d_train, convert_dates = FALSE)
  expect_true(!all(c("date_col", "posixct_col", "col_DTS") %in% names(dd)))
})

test_that("prep_data works when certain column types are missing", {
  d2 <- d_train %>%
    dplyr::select(-dplyr::one_of(c("date_col", "posixct_col",
                                   "col_DTS", "drum_flag", "guitar_flag")))
  d_clean <- prep_data(d = d2, outcome = is_ween, song_id, make_dummies = FALSE)
  expect_equal(unique(d_clean$weirdness[is.na(d2$weirdness)]),
               mean(d2$weirdness, na.rm = TRUE))
  expect_true(all.equal(droplevels(d_clean$genre[!is.na(d2$genre)]),
                        d2$genre[!is.na(d2$genre)]))
  expect_true(all(d_clean$genre[is.na(d2$genre)] == "missing"))
})

test_that("impute gives warning when column has 50% or more NA", {
  d_train$reaction[1:200] <- NA
  expect_warning(d_clean <- prep_data(d = d_train, outcome = is_ween, song_id),
                 regexp = "reaction")
})

test_that("impute works with params", {
  d_clean <- prep_data(d_train, outcome = is_ween, song_id,
                       impute = list(numeric_method = "knnimpute",
                                     nominal_method = "bagimpute",
                                     numeric_params = list(knn_K = 5),
                                     nominal_params = NULL),
                       make_dummies = FALSE)
  expect_true(is.numeric(d_clean$weirdness))
  expect_false(any(is.na(d_clean$weirdness)))
  expect_true("missing" %in% levels(d_clean$genre))
})

test_that("impute works with partial/extra params", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       impute = list(numeric_method = "bagimpute"))
  m <- missingness(d_clean)
  expect_true(all(m$percent_missing == 0))
  expect_warning(
    d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                         impute = list(numeric_method = "knnimpute",
                                       numeric_params = list(knn_K = 5),
                                       the_best_params = "Moi!")),
    regexp = "the_best_params")
})

test_that("rare factors go to other by default", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id)
  exp <- c("CA", "CT", "MA", "NY", "other")
  # Should get a column for all but one of the exp levels:
  expect_equal(sum(purrr::map_lgl(exp, ~ any(grepl(.x, names(d_clean))))),
               length(exp) - 1)
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id, make_dummies = FALSE)
  expect_true(all(exp %in% levels(d_clean$state)))
  exp <- c("Dislike", "Huh", "Love", "Mixed", "missing")
  expect_true(all(exp %in% levels(d_clean$reaction)))
})

test_that("rare factors unchanged when FALSE", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       collapse_rare_factors = FALSE, make_dummies = FALSE,
                       add_levels = FALSE)
  exp <- c("CA", "CT", "MA", "NH", "NY", "VT", "missing")
  expect_equal(levels(d_clean$state), exp)
})

test_that("absent levels get dummified if rare factors are collapsed", {
  levels(d_train$genre) <- c(levels(d_train$genre), "Muzak")
  pd <- prep_data(d_train, song_id, collapse_rare_factors = FALSE)
  expect_true("genre_Muzak" %in% names(pd))
})

test_that("rare factors go to other when a threshold is specified", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       collapse_rare_factors = 0.15, make_dummies = FALSE,
                       add_levels = FALSE)
  exp <- c("CA", "NY", "other")
  expect_equal(levels(d_clean$state), exp)
})

test_that("centering and scaling work", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       center = TRUE, scale = TRUE)
  expect_equal(mean(d_clean$length), 0, tol = .01)
  expect_equal(mean(d_clean$weirdness), 0, tol = .01)
  expect_equal(sd(d_clean$length), 1, tol = .01)
  expect_equal(sd(d_clean$weirdness), 1, tol = .01)
})

test_that("dummy columns are created as expected", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id,
                       convert_dates = FALSE, make_dummies = TRUE,
                       add_levels = FALSE)
  exp <- c("genre_Jazz", "genre_Rock", "genre_missing")
  n <- names(dplyr::select(d_clean, dplyr::starts_with("genre")))
  expect_true(all(exp %in% n))
  exp <- c("reaction_Huh", "reaction_Love", "reaction_Mixed",
           "reaction_missing" )
  n <- names(dplyr::select(d_clean, dplyr::starts_with("reaction")))
  expect_true(all(n == exp))
})

test_that("Output of impute is same for tibble vs data frame", {
  expect_equal(
    prep_data(d_train),
    prep_data(tibble::as_tibble(d_train)))
})

test_that("recipe attr is a recipe class object", {
  dd <- prep_data(d_train)
  expect_true("recipe" %in% names(attributes(dd)))
  expect_s3_class(attr(dd, "recipe"), "recipe")
})

test_that("only the first few rows of training data are stored in the recipe", {
  expect_true(nrow(attr(d_prep, "recipe")$template) <= 10)
})

test_that("names of ignored columns get attached as attribute to recipe", {
  d_clean <- prep_data(d = d_train, outcome = is_ween, song_id)
  expect_true("recipe" %in% names(attributes(d_clean)))
  recipe_attrs <- attributes(attr(d_clean, "recipe"))
  expect_true("ignored_columns" %in% names(recipe_attrs))
  expect_true(recipe_attrs$ignored_columns == "song_id")
  multi_ignore <- prep_data(d_train, song_id, guitar_flag, state)
  expect_true(all.equal(attr(attr(multi_ignore, "recipe"), "ignored_columns"),
                        c("song_id", "guitar_flag", "state")))
})

test_that("print works as expected", {
  messaged <- capture_messages(catted <- capture.output(d_prep))
  expect_true(any(grepl("Recipe", messaged)))
  expect_true(any(grepl("prepped", messaged)))
  expect_true(any(grepl("Recipe", catted)))
  expect_true(any(grepl("tibble", catted)))
})

test_that("prep_data applies recipe from training on test data", {
  expect_equal(d_reprep, d_reprep2)
  expect_equal(unique(d_reprep$weirdness[is.na(d_test$weirdness)]),
               mean(d_train$weirdness, na.rm = TRUE))
  expect_true(all(d_reprep$genre_missing[is.na(d_test$genre)] == 1))
})

test_that("Unignored variables present in training but not deployment error", {
  expect_error(prep_data(dplyr::select(d_test, -length), recipe = d_prep))
  expect_s3_class(prep_data(dplyr::select(d_test, -song_id), recipe = d_prep),
                  "prepped_df")
})

test_that("New variables present in deployment get ignored with a warning", {
  big_d <- dplyr::mutate(d_train, extra = seq_len(nrow(d_train)))
  expect_warning(pd <- prep_data(big_d, recipe = attr(d_prep, "recipe")),
                 regexp = "extra")
  expect_true(all.equal(pd$extra, seq_len(nrow(d_train))))
})

test_that("All numeric variables aren't a problem", {
  d <- data.frame(x = 1:5, y = 5:1, id_var = letters[1:5])
  expect_s3_class(prep_data(d, id_var), "prepped_df")
  expect_s3_class(prep_data(d, outcome = "id_var"), "prepped_df")
})

test_that("All nominal variables aren't a problem", {
  d <- data.frame(x = letters, y = rev(letters), id_var = 1:26)
  expect_s3_class(prep_data(d, id_var), "prepped_df")
  expect_s3_class(prep_data(d, outcome = id_var), "prepped_df")
})

test_that("remove_near_zero_variance is respected, works, and messages", {
  d_train <- dplyr::mutate(d_train,
                           a_nzv_col = c("rare", rep("common", nrow(d_train) - 1)))
  expect_message(def <- prep_data(d_train), regexp = "a_nzv_col")
  expect_false("a_nzv_col" %in% names(def))
  # nzv_col should be removed in deployement even if it has variance
  d_test <- dplyr::mutate(d_test,
                          a_nzv_col = sample(letters, nrow(d_test), replace = TRUE))
  expect_message(pd <- prep_data(d_test, recipe = def), regexp = "a_nzv_col")
  expect_false("a_nzv_col" %in% names(def))
  stay <- prep_data(d_train, remove_near_zero_variance = FALSE, make_dummies = FALSE)
  expect_true("a_nzv_col" %in% names(stay))
  expect_error(prep_data(dplyr::select(d_train, a_nzv_col, is_ween), outcome = is_ween),
               "github.com")
})

test_that("collapse_rare_factors works", {
  d_train <- dplyr::mutate(d_train, imbal = c(letters, rep("common", nrow(d_train) - 26)))
  pd <- prep_data(d_train,
                  collapse_rare_factors = FALSE,
                  make_dummies = FALSE)
  expect_true(all(letters %in% pd$imbal))
  coll <- prep_data(d_train, make_dummies = FALSE)
  expect_false(any(letters %in% coll$imbal))
})

test_that("collapse_rare_factors respects threshold", {
  # 1% < a < 2%
  d_train <- dplyr::mutate(d_train, imbal = c(rep("a", 4),
                                              rep("common", nrow(d_train) - 4)))
  def <- prep_data(d_train, remove_near_zero_variance = FALSE,
                   make_dummies = FALSE)
  below_thresh <- prep_data(d_train, remove_near_zero_variance = FALSE,
                            make_dummies = FALSE, collapse_rare_factors = .02)
  above_thresh <- prep_data(d_train, remove_near_zero_variance = FALSE,
                            make_dummies = FALSE, collapse_rare_factors = .01)
  never <- prep_data(d_train, remove_near_zero_variance = FALSE,
                     make_dummies = FALSE, collapse_rare_factors = FALSE)
  expect_false("a" %in% def$imbal)
  expect_false("a" %in% below_thresh$imbal)
  expect_true("a" %in% above_thresh$imbal)
  expect_true("a" %in% never$imbal)
  expect_true("other" %in% def$imbal)
  expect_true("other" %in% below_thresh$imbal)
  expect_false("other" %in% above_thresh$imbal)
  expect_false("other" %in% never$imbal)
})

test_that("missing and other are added to all nominal columns", {
  d <- data.frame(has_missing = c(rep(NA, 10), rep("b", 20)),
                  has_rare = c("rare", rep("common", 29)),
                  has_both = c("rare", NA, rep("common", 28)),
                  has_neither = c(rep("cat1", 15), rep("cat2", 15)))
  pd <- prep_data(d, make_dummies = FALSE, remove_near_zero_variance = FALSE,
                  collapse_rare_factors = .05)
  expect_true(all(purrr::map_lgl(pd, ~ all(c("other", "missing") %in% levels(.x)))))

  scrambled <- data.frame(has_missing = c(rep("cat1", 15), rep("cat2", 15)),
                          has_rare = c(rep(NA, 10), rep("b", 20)),
                          has_both = c("rare", rep("common", 29)),
                          has_neither = c("rare", NA, rep("common", 28)))
  suppressWarnings(scrambled_prep <- prep_data(scrambled, recipe = attr(pd, "recipe")))
  expect_true(all(purrr::map_lgl(scrambled_prep, ~ all(c("other", "missing") %in% levels(.x)))))
})

test_that("add_levels doesn't add levels to outcome", {
  d <- data.frame(x = c("A", "B"), y = 1:2)
  pd <- prep_data(d, outcome = x, make_dummies = FALSE, add_levels = FALSE)
  expect_false(any(c("other", "missing") %in% levels(pd$x)))
})

test_that("prep_data respects add_levels = FALSE", {
  d <- data.frame(x = c("A", "B"), y = 1:2)
  pd <- prep_data(d, add_levels = FALSE, make_dummies = FALSE, impute = FALSE)
  expect_false(any(c("other", "missing") %in% levels(pd$x)))
})

test_that("If outcome to prep_data is or looks like logical, get informative error", {
  d_train <- d_train %>% dplyr::mutate(is_ween = is_ween == "Y")
  expect_error(prep_data(d_train, outcome = is_ween), "logical")
  d_train <- d_train %>% dplyr::mutate(is_ween = as.character(is_ween == "Y"))
  expect_error(prep_data(d_train, outcome = is_ween), "logical")
})

test_that("prep_data leaves newly created dummies as 0/1", {
  d <- data.frame(x = 1:10, y = rep(letters[1:2], len = 10))
  expect_true(all(prep_data(d, center = TRUE, scale = TRUE)[["y_b"]] %in% 0:1))
})

test_that("If recipe provided but no outcome column, NA-outcome column isn't created", {
  expect_false("is_ween" %in% names(
    prep_data(dplyr::select(d_test, -is_ween), song_id, recipe = attr(d_prep, "recipe"))
  ))
})

test_that("prep_data doesn't remove outcome variable specified in recipe", {
  d <- data.frame(x = 1:5, y = 6:10)
  pd <- prep_data(d, outcome = y)
  expect_true("y" %in% names(prep_data(data.frame(x = 1, y = 2), recipe = pd)))
})

test_that("predict regression with prep doesn't choke without outcome", {
  prep_data(pima_diabetes[1:50, ], outcome = age) %>%
    tune_models(age, models = "rf") %>%
    predict(dplyr::select(pima_diabetes[51:55, ], -age)) %>%
    expect_s3_class("predicted_df")
})

test_that("predict classification with prep doesn't choke without outcome", {
  prep_data(pima_diabetes[1:50, ], outcome = diabetes) %>%
    tune_models(diabetes, models = "rf") %>%
    predict(dplyr::select(pima_diabetes[51:55, ], -diabetes)) %>%
    expect_s3_class("predicted_df")
})

test_that("prep_data attaches missingness to recipe as attribute", {
  expect_true("missingness" %in% names(attributes(attr(d_prep, "recipe"))))
  expect_equal(attr(attr(d_prep, "recipe"), "missingness"),
               missingness(d_train, return_df = FALSE))
})

test_that("prep_data warns when there's missingness in a column that didn't have missingness in training", {
  d_test$guitar_flag[1] <- NA
  expect_warning(prep_data(d_test, recipe = d_prep), "guitar_flag")
})

test_that("prep_data doesn't warn for new missingness in ID or outcome columns", {
  d_test$is_ween[1:5] <- NA
  d_test$song_id[1:5] <- NA
  expect_warning(prep_data(d_test, recipe = d_prep), NA)
})

test_that("prep_data attaches factor levels to recipe as attribute", {
  rec <- attr(d_prep, "recipe")
  expect_true("factor_levels" %in% names(attributes(rec)))
  expect_setequal(names(attr(rec, "factor_levels")), c("genre", "reaction", "state", "is_ween"))
})

test_that("prep_data tells you if you forgot to name your outcome argument", {
  expect_message(prep_data(d_train, song_id, is_ween), "outcome")
})

test_that("prep_data warns iff factor contrast options are dummy", {
  oc <- options("contrasts")
  on.exit(options(contrasts = oc[[1]]))
  options(contrasts = c("contr.dummy", "contr.poly"))
  expect_warning(prep_data(d_train, song_id, outcome = is_ween), "contrasts")
  options(contrasts = c("contr.treatment", "contr.poly"))
  expect_warning(prep_data(d_train, song_id, outcome = is_ween), NA)
})

test_that("prep_data errors informatively 0/1 factor outcomes", {
  dd <- data.frame(y = factor(rep(0:1, 10)),
                   x1 = sample(letters, 20),
                   x2 = rnorm(20))
  expect_error(prep_data(dd, outcome = y), "character")
})

test_that("data prepped on existing recipe returns ID columns", {
  # Only difference in the prep here is the ID col isn't specified,
  # but that's remembered in the recipe.
  setdiff(names(d_reprep),
          names(prep_data(d_test, recipe = attr(d_prep, "recipe"))))
})
