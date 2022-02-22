functions {
  matrix covar_fun (real alpha) {
    matrix[1, 1] covariance;
    covariance[1, 1] = alpha;
    return covariance;
  }
}

transformed data {
 array[1] int y;
 array[1]  int n_samples;
 vector[1] ye;

  vector[1] phi;
  array[1] vector[1] x;
  array[1] real delta;
  array[1] int delta_int;

  vector[1] theta0;
}

parameters {
  real alpha;
  vector[1] theta0_v;
}

model {
  target +=
    laplace_marginal_poisson_log_lpmf(y | n_samples, covar_fun, theta0, alpha);
  target +=
    laplace_marginal_poisson_log_lpmf(y | n_samples, ye, covar_fun, theta0, alpha);

  y ~ laplace_marginal_poisson_log(n_samples, covar_fun, theta0, alpha);

  y ~ laplace_marginal_poisson_log(n_samples, ye, covar_fun, theta0, alpha);
}

generated quantities {
  /*
  vector[1] theta_pred =
    laplace_poisson_log_rng(y, n_samples, K, phi, x, delta, delta_int,
                           theta0);
  theta_pred = laplace_poisson_log_rng(y, n_samples, ye, K, phi, x,
                                          delta, delta_int, theta0);
 */
}
