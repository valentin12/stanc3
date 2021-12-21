functions {
  array[] real dz_dt(real t,       // time
               array[] real z) {     // system state {prey, predator}) {
    real u = z[1];
    real v = z[2];

    real du_dt = v * u;
    real dv_dt = u * v;

    return { du_dt, dv_dt };
  }
}
data {
  int<lower = 0> N;          // number of measurement times
  array[N] real ts;                // measurement times > 0
  array[2] real y_init;            // initial measured populations
  array[N, 2] real<lower = 0> y;   // measured populations
}
parameters {
  array[2] real<lower = 0> z_init;  // initial population
  array[2] real<lower = 0> sigma;   // measurement errors
}
transformed parameters {
  array[N, 2] real z
  = ode_bdf_tol(dz_dt, z_init, 0.0, ts,
            1e-5, 1e-3, 500);
}
model {
}
