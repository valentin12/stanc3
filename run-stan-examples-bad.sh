for foldername in folder/*;
  do cd "src/stan/examples-bad";
  for filename in *.stan;
    do printf "\n\n $filename \n ---------\n"; ./../../../stan.native "$filename"   ;
  done  > ../../../"stan-examples-bad-out.log" 2> ../../../"stan-examples-bad-errors.log" ;
  cd ../..;
done
# TODO: fix this to check that these all raise. Also, make sure we add the duplicate names to the examples-bad folder.