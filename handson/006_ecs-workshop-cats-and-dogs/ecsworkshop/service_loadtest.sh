for i in {1..100}
do
ab -c 200 -n 200 -t 30 demogo-alb-903552715.ap-northeast-1.elb.amazonaws.com/ 
done
