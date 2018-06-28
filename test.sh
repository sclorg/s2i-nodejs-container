for subdir in `find . -type d` 
do
if [ -f ./$subdir/layer.tar ]   
then   
        echo "extracting"; echo $subdir
        tar xvf ./$subdir/layer.tar -C ./$subdir >> log.text
#       echo Yes;echo $subdir
 else 
         echo "not";echo $subdir
 fi 
 done
