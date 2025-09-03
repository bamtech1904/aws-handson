for i in {1..30}
do
ab -c 800 -n 800 -t 10 demogo-alb-903552715.ap-northeast-1.elb.amazonaws.com/
ab -c 800 -n 800 -t 10 demogo-alb-903552715.ap-northeast-1.elb.amazonaws.com/cats
ab -c 800 -n 800 -t 10 demogo-alb-903552715.ap-northeast-1.elb.amazonaws.com/dogs
done