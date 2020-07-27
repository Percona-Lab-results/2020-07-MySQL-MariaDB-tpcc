HOST="--mysql-socket=/tmp/mysql.sock"
#HOST="--mysql-host=127.0.0.1"
MYSQLDIR=/opt/vadim/Percona-Server-5.7.21-20-Linux.x86_64.ssl100
DATADIR=/mnt/nvmi/sysbench
CONFIG=cnf/my.cnf
TEST=oltp_point_select

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

startmysql(){
  sync
  sysctl -q -w vm.drop_caches=3
  echo 3 > /proc/sys/vm/drop_caches
  ulimit -n 1000000
  numactl --interleave=all /opt/vadim/Percona-Server-5.7.21-20-Linux.x86_64.ssl100/bin/mysqld --defaults-file=$CONFIG --basedir=/opt/vadim/Percona-Server-5.7.21-20-Linux.x86_64.ssl100 --user=root --innodb_buffer_pool_size=${BP}G &
}

shutdownmysql(){
  echo "Shutting mysqld down..."
  $MYSQLDIR/bin/mysqladmin shutdown -S /tmp/mysql.sock
}

waitmysql(){
        set +e

        while true;
        do
                $MYSQLDIR/bin/mysql -Bse "SELECT 1" mysql

                if [ "$?" -eq 0 ]
                then
                        break
                fi

                sleep 30

                echo -n "."
        done
        set -e
}

initialstat(){
  cp $CONFIG $OUTDIR
  cp $0 $OUTDIR
}

collect_mysql_stats(){
  $MYSQLDIR/bin/mysqladmin ext -i10 > $OUTDIR/mysqladminext.txt &
  PIDMYSQLSTAT=$!
}
collect_dstat_stats(){
  vmstat 1 > $OUTDIR/vmstat.out &
  PIDDSTATSTAT=$!
}


# cycle by buffer pool size

xfs_fsr /dev/sda5

RUNDIR=res-tpcc-8.0.21-`date +%F-%H-%M`
#for BP in 100 90 80 70 60 50 40 30 20 10 5
for BP in 25
do

#echo "Restoring backup"
#rm -fr /data/sam/vadim/mysql
#cp -r /data/sam/vadim/mysql.innoback /data/sam/vadim/mysql

fstrim /mnt/data

#startmysql &
#sleep 10
#waitmysql

runid="ps8-BP$BP.SSD.io2000"
#runid="mariadb-10.5.4.BP$BP"

# perform warmup
#./tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=3600 --threads=56 --report-interval=1 --tables=10 --scale=100 --use_fk=1 run |  tee -a $OUTDIR/res.txt

for i in  56
#for i in 1 3 6 12 24 48 96
do

        OUTDIR=$RUNDIR/$runid/
        mkdir -p $OUTDIR

        # start stats collection

        time=10000
        ./tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=$time --threads=$i --report-interval=1 --tables=10 --scale=100 --use_fk=0 --report-csv=yes run |  tee -a $OUTDIR/res.thr${i}txt

        sleep 30
done

#shutdownmysql

done
