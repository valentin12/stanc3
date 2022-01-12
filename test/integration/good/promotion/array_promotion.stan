functions {
   void printer(array[] real x){
     print(x);
   }

   real nested(array[,] complex zs){
     return num_elements(zs);
   }
}

model {
  array[3] int d = {1,2,3};
  printer(d);
  print(nested({d,d}));
}
