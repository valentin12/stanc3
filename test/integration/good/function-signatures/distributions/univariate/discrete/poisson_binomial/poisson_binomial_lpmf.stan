data {
  int d_int;
  array[d_int] int d_int_array;
  real d_real;
  vector[d_int] d_vector;
  row_vector[d_int] d_row_vector;
}
transformed data {
  real transformed_data_real;
  transformed_data_real = poisson_binomial_lpmf(d_int| d_vector);
  transformed_data_real = poisson_binomial_lpmf(d_int| d_row_vector);
  transformed_data_real = poisson_binomial_lpmf(d_int_array| d_vector);
  transformed_data_real = poisson_binomial_lpmf(d_int_array| d_row_vector);
}
parameters {
  real p_real;
  vector[d_int] p_vector;
  row_vector[d_int] p_row_vector;
  real y_p;
}
transformed parameters {
  real transformed_param_real;
  transformed_param_real = poisson_binomial_lpmf(d_int| d_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int| p_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int| d_row_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int| p_row_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int_array| d_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int_array| p_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int_array| d_row_vector);
  transformed_param_real = poisson_binomial_lpmf(d_int_array| p_row_vector);
}
model {
  y_p ~ normal(0, 1);
}

