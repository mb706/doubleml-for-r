context("Unit tests for PLIV")

library("mlr3learners")
library('data.table')
library('mlr3')

lgr::get_logger("mlr3")$set_threshold("warn")

test_cases = expand.grid(learner = c('regr.lm', 'regr.cv_glmnet'),
                         dml_procedure = c('dml1', 'dml2'),
                         se_reestimate = c(FALSE),
                         score = c('partialling out'),
                         i_setting = 1:(length(data_pliv)),
                         stringsAsFactors = FALSE)
test_cases['test_name'] = apply(test_cases, 1, paste, collapse="_")

patrick::with_parameters_test_that("Unit tests for PLIV:",
                                   .cases = test_cases, {
  
  learner_pars <- get_default_mlmethod_pliv(learner)
  n_rep_boot = 498
  
  set.seed(i_setting)
  pliv_hat <- dml_plriv(data_pliv[[i_setting]], y = "y", d = "d", z = 'z',
                        k = 5, mlmethod = learner_pars$mlmethod,
                        params = learner_pars$params,
                        dml_procedure = dml_procedure, score = score,
                        se_type = score,
                        bootstrap = "normal",  nRep = n_rep_boot)
  theta <- coef(pliv_hat)
  se <- pliv_hat$se
  
    
  set.seed(i_setting)
  
  params_OOP <- rep(list(rep(list(learner_pars$params), 1)), 1)
  
  Xnames = names(data_pliv[[i_setting]])[names(data_pliv[[i_setting]]) %in% c("y", "d", "z") == FALSE]
   
  data_ml = double_ml_data_from_data_frame(data_pliv[[i_setting]], y_col = "y", 
                              d_cols = "d", x_cols = Xnames, z_cols = "z")

  double_mlpliv_obj = DoubleMLPLIV$new(data_ml, 
                                     n_folds = 5,
                                     ml_g = learner_pars$mlmethod$mlmethod_g,
                                     ml_m = learner_pars$mlmethod$mlmethod_m,
                                     ml_r = learner_pars$mlmethod$mlmethod_r,
                                     dml_procedure = dml_procedure, 
                                     score = score)
  
  double_mlpliv_obj$set__ml_nuisance_params(nuisance_part = "ml_g", 
                                           treat_var = "d",
                                            params = learner_pars$params$params_g)
  double_mlpliv_obj$set__ml_nuisance_params(nuisance_part = "ml_m", 
                                           treat_var = "d",
                                            params = learner_pars$params$params_m)
  double_mlpliv_obj$set__ml_nuisance_params(nuisance_part = "ml_r", 
                                           treat_var = "d",
                                            params = learner_pars$params$params_r)
  
  double_mlpliv_obj$fit()
  theta_obj <- double_mlpliv_obj$coef
  se_obj <- double_mlpliv_obj$se
  
  # bootstrap
  # double_mlpliv_obj$bootstrap(method = 'normal',  n_rep = n_rep_boot)
  # boot_theta_obj = double_mlpliv_obj$boot_coef
  
  # at the moment the object result comes without a name
  expect_equal(theta, theta_obj, tolerance = 1e-8)
  expect_equal(se, se_obj, tolerance = 1e-8)
  # expect_equal(as.vector(pliv_hat$boot_theta), as.vector(boot_theta_obj), tolerance = 1e-8)
  
}
)
