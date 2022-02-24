functions {
  matrix covar_fun (real alpha) {
    matrix[1, 1] covariance;
    return covariance;
  }
}

transformed data {
 array[1] int y;
 array[1]  int n_samples;
  vector[1] theta0;
}

parameters {
  real alpha;
}

model {
  target +=
    laplace_marginal_poisson_log_lpmf(y | n_samples, theta0, covar_fun, alpha);
  y ~ laplace_marginal_poisson_log(n_samples, theta0, covar_fun, alpha);


  // each of these produces a unique typeerror
  // target += laplace_marginal_poisson_log_lpmf(y , theta0, covar_fun, alpha);
  // target += laplace_marginal_poisson_log_lpmf( covar_fun, alpha);
  // target += laplace_marginal_poisson_log_lpmf(y | n_samples, theta0, covar_fun);
  // target += laplace_marginal_poisson_log_lpmf(y | n_samples, theta0, covar_fun, alpha, alpha);
  // this style also does
  // y ~ laplace_marginal_poisson_log(n_samples, theta0, covar_fun);

}

