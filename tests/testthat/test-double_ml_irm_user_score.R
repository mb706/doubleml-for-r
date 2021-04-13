context("Unit tests for IRM, callable score")

library("mlr3learners")

lgr::get_logger("mlr3")$set_threshold("warn")

# externally provided score function
score_fct = function(y, d, g0_hat, g1_hat, m_hat, smpls) {
  n_obs = length(y)
  u1_hat = y - g1_hat
  u0_hat = y - g0_hat

  psi_b = g1_hat - g0_hat + d * (u1_hat) / m_hat -
    (1 - d) * u0_hat / (1 - m_hat)
  psi_a = rep(-1, n_obs)
  psis = list(
    psi_a = psi_a,
    psi_b = psi_b)
  return(psis)
}

on_cran = !identical(Sys.getenv("NOT_CRAN"), "true")
if (on_cran) {
  test_cases = expand.grid(
    learner = "regr.glmnet",
    learner_m = "classif.glmnet",
    dml_procedure = "dml2",
    i_setting = 1:(length(data_irm)),
    trimming_threshold = 0,
    stringsAsFactors = FALSE)
  test_cases["test_name"] = apply(test_cases, 1, paste, collapse = "_")
} else {
  test_cases = expand.grid(
    learner = "regr.glmnet",
    learner_m = "classif.glmnet",
    dml_procedure = c("dml1", "dml2"),
    i_setting = 1:(length(data_irm)),
    trimming_threshold = c(0, 0.01),
    stringsAsFactors = FALSE)
  test_cases["test_name"] = apply(test_cases, 1, paste, collapse = "_")
}

patrick::with_parameters_test_that("Unit tests for IRM, callable score:",
  .cases = test_cases, {
    n_rep_boot = 498

    set.seed(i_setting)
    Xnames = names(data_irm[[i_setting]])[names(data_irm[[i_setting]]) %in% c("y", "d", "z") == FALSE]
    data_ml = double_ml_data_from_data_frame(data_irm[[i_setting]],
      y_col = "y",
      d_cols = "d", x_cols = Xnames)

    double_mlirm_obj = DoubleMLIRM$new(data_ml,
      n_folds = 5,
      ml_g = lrn(learner),
      ml_m = lrn(learner_m),
      dml_procedure = dml_procedure,
      score = "ATE",
      trimming_threshold = trimming_threshold)
    double_mlirm_obj$fit()
    theta_obj = double_mlirm_obj$coef
    se_obj = double_mlirm_obj$se

    set.seed(i_setting)
    double_mlirm_obj_score = DoubleMLIRM$new(data_ml,
      n_folds = 5,
      ml_g = lrn(learner),
      ml_m = lrn(learner_m),
      dml_procedure = dml_procedure,
      score = score_fct,
      trimming_threshold = trimming_threshold)
    double_mlirm_obj_score$fit()
    theta_obj_score = double_mlirm_obj_score$coef
    se_obj_score = double_mlirm_obj_score$se

    # bootstrap
    # double_mlirm_obj$bootstrap(method = 'normal',  n_rep = n_rep_boot)
    # boot_theta_obj = double_mlirm_obj$boot_coef
    #
    # at the moment the object result comes without a name
    expect_equal(theta_obj_score, theta_obj, tolerance = 1e-8)
    expect_equal(se_obj_score, se_obj, tolerance = 1e-8)
    # expect_equal(as.vector(irm_hat$boot_theta), as.vector(boot_theta_obj), tolerance = 1e-8)
  }
)