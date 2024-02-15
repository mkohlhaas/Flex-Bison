for i in tests/*.obj;do echo $i; cat $i | ./build/obj;done
