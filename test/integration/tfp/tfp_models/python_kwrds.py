
import numpy as np__
import tensorflow as tf__
import tensorflow_probability as tfp__
tfd__ = tfp__.distributions
tfb__ = tfp__.bijectors
from tensorflow.python.ops.parallel_for import pfor as pfor__

def yield__(b):
  return b * tf__.cast(3, tf__.float64)
   
def func(await__):
  return await__ + tf__.cast(1, tf__.float64)
   
class python_kwrds_model(tfd__.Distribution):

  def __init__(self, lambda__):
    self.lambda__ = lambda__
    self.d = lambda__ / tf__.cast(3, tf__.float64)
     
  
  def log_prob_one_chain(self, params):
    target = 0
    
    # Data
    lambda__ = self.lambda__
    
    # Transformed data
    d = self.d
    
    # Parameters
    finally__ = tf__.cast(params[0], tf__.float64)
    
    # Target log probability computation
    assert__ = finally__ + tf__.cast(2, tf__.float64)
    target += tf__.reduce_sum(tfd__.Normal(yield__(assert__),
                                           tf__.cast(1, tf__.float64)).log_prob(d))
    target += tf__.reduce_sum(tfd__.Binomial(tf__.cast(10, tf__.float64),
                                             func(finally__)).log_prob(lambda__))
    return target
     
  def log_prob(self, params):
    return tf__.vectorized_map(self.log_prob_one_chain, params)
    
     
  def parameter_shapes(self, nchains__):
    lambda__ = self.lambda__
    return [(nchains__, )]
     
  def parameter_bijectors(self):
    lambda__ = self.lambda__
    return [tfb__.Identity()]
     
  def parameter_names(self):
    return ["finally__"]
     
model = python_kwrds_modelWarning in 'stan_models/python_kwrds.stan', line 13, column 12: Found int division:
  lambda / 3
Values will be rounded towards zero. If rounding is not desired you can write
the division as
  lambda / 3.0
If rounding is intended please use the integer division operator %/%.
Identifier finally is a reserved word in python, renamed to finally__
Identifier assert is a reserved word in python, renamed to assert__
Identifier lambda is a reserved word in python, renamed to lambda__
Identifier yield is a reserved word in python, renamed to yield__
Identifier await is a reserved word in python, renamed to await__
Identifier finally is a reserved word in python, renamed to finally__
Identifier finally is a reserved word in python, renamed to finally__
Identifier assert is a reserved word in python, renamed to assert__
Identifier yield is a reserved word in python, renamed to yield__
Identifier lambda is a reserved word in python, renamed to lambda__
Identifier finally is a reserved word in python, renamed to finally__
Identifier lambda is a reserved word in python, renamed to lambda__
Identifier await is a reserved word in python, renamed to await__
Identifier finally is a reserved word in python, renamed to finally__
Identifier assert is a reserved word in python, renamed to assert__
Identifier assert is a reserved word in python, renamed to assert__
Identifier finally is a reserved word in python, renamed to finally__
Identifier assert is a reserved word in python, renamed to assert__
Identifier assert is a reserved word in python, renamed to assert__
Identifier lambda is a reserved word in python, renamed to lambda__