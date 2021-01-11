#!/bin/bash -e

#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Usage:
#    ./run_scenarios.sh -a <application> -n <testcase> -p <priming> -i <invokes> -q <queries>
#
# Examples:
#    ./run_scenarios.sh -a samplecc -n FAB-3833-2i -p FAB-3810-2q -i FAB-3833-2i -q FAB-3810-2q

########## CI test ##########

# defaults
launchNtwk="none"
preConfig="none"
application="none"
network="none"
priming="none"
invokes="none"
queries="none"

TESTCASE="pteTest"

# usage
usage () {
    echo -e "\nUsage:\t./run_scenarios.sh -a <application> -n <network> --preconfig <network> -p <prime> -i <invokes> -q <queries>"
    echo
    echo -e "\t-h, --help\tView this help message"
    echo
    echo -e "\t-a, --application\tapplication"
    echo -e "\t\tDefault: none"
    echo
    echo -e "\t-n, --network\tlaunch network and preconfiguration"
    echo -e "\t\tDefault: none. Note: cannot be used with --preconfig"
    echo
    echo -e "\t--preconfig\tpreconfiguration"
    echo -e "\t\tDefault: none. Note: cannot be used with -n or --network"
    echo
    echo -e "\t-p, --prime\tpriming"
    echo -e "\t\tDefault: none"
    echo
    echo -e "\t-i, --invoke\tinvokes"
    echo -e "\t\tDefault: none"
    echo
    echo -e "\t-q, --query\tqueries"
    echo -e "\t\tDefault: none"
    echo
    echo -e "\tExamples:"
    echo -e "\t    ./run_scenarios.sh -a samplecc -n FAB-3833-2i -p FAB-3810-2q -i FAB-3833-2i -q FAB-3810-2q"
    echo -e "\t    ./run_scenarios.sh -a samplecc --preconfig FAB-3833-2i -p FAB-3810-2q -i FAB-3833-2i -q FAB-3810-2q"
    echo
}


# input parameters
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in

      -h | --help)
          usage              # displays usage info
          exit 0             # exit cleanly, since the use just asked for help/usage info
          ;;

      -a | --application)
          shift
          application=$1     # application chaincode
          shift
          ;;

      -n | --network)
          if [ $network != "none" ]; then
              echo "Error: cannot use option $1 with option --preconfig"
              usage
              exit 1
          fi

          shift
          network=$1         # network
          TESTCASE=$network
          launchNtwk="yes"   # launch network
          preConfig="yes"    # preconfig
          shift
          ;;

      --preconfig)
          if [ $network != "none" ]; then
              echo "Error: cannot use option $1 with option -n"
              usage
              exit 1
          fi

          shift
          network=$1         # network
          TESTCASE=$network
          preConfig="yes"    # preconfig
          shift
          ;;

      -p | --prime)
          shift
          priming=$1         # priming
          shift
          ;;

      -i | --invoke)
          shift
          invokes=$1         # invokes
          shift
          ;;

      -q | --query)
          shift
          queries=$1         # queries
          shift
          ;;

      *)
          echo "Error: Unrecognized command line argument: $1"
          usage
          exit 1
          ;;
    esac
done

echo "[$0] launchNtwk=$launchNtwk preConfig=$preConfig"
echo "[$0] network=$network priming=$priming invokes=$invokes queries=$queries"
echo "[$0] TESTCASE=$TESTCASE application=$application"

LOGDIR="../Logs"
mkdir -p $LOGDIR

pteReport="../../pteReport.txt"
# remove existing pteReport
if [ -e $pteReport ]; then
    echo "[$0] remove $pteReport"
    rm -f $pteReport
fi

CIpteReport=$LOGDIR"/"$TESTCASE"-pteReport.log"
if [ -e $CIpteReport ]; then
    rm -f $CIpteReport
fi

cd ../scripts

#### pre-process
if [ $network != "none" ]; then
    #### Launch network
    if [ $launchNtwk != "none" ]; then
        echo "[$0] ./test_driver.sh -n -m $network"
        ./test_driver.sh -n -m $network
    fi

    #### pre-configuration: create/join channel, install/instantiate chaincode
    if [ $application != "none" ] && [ $preConfig != "none" ]; then
        echo "[$0] ./test_driver.sh -m $network -p -c $application"
        ./test_driver.sh -m $network -p -c $application
    fi
fi

#### ledger priming
if [ $priming != "none" ]; then
    echo "[$0] ./test_driver.sh -t $priming"
    ./test_driver.sh -t $priming

    #### remove PTE log from ledger priming
    echo "[$0] remove PTE log from ledger priming"
    rm -f $LOGDIR/"$priming"*.log

    # remove pteReport from ledger priming
    if [ -e $pteReport ]; then
        echo "[$0] remove $pteReport"
        rm -f $pteReport
    fi
fi


#### execute invokes
if [ $invokes != "none" ]; then
    echo "[$0] ./test_driver.sh -t $invokes"
    ./test_driver.sh -t $invokes

    #### set the CIpteReport name to run testcase if TESTCASE is not set
    if [ $TESTCASE == "pteTest" ]; then
        CIpteReport=$LOGDIR"/"$invokes"-pteReport.log"
        if [ -e $CIpteReport ]; then
            rm -f $CIpteReport
        fi
        # print testcase name at the top of CIpteReport file
        echo "PTE testcase: $invokes" >> $CIpteReport
    else
        # print testcase name at the top of CIpteReport file
        echo "PTE testcase: $TESTCASE" >> $CIpteReport
    fi
    #### calculate overall invoke TPS from pteReport
    echo "[$0] testcase [$invokes] CIpteReport=$CIpteReport"
    node get_pteReport.js $pteReport

    cat $pteReport >> $CIpteReport
    rm -f $pteReport
fi


#### execute queries
if [ $queries != "none" ]; then
    echo "[$0] ./test_driver.sh -t $queries"
    ./test_driver.sh -t $queries

    #### set the CIpteReport name to run testcase if TESTCASE is not set
    if [ $TESTCASE == "pteTest" ]; then
        CIpteReport=$LOGDIR"/"$queries"-pteReport.log"
        if [ -e $CIpteReport ]; then
            rm -f $CIpteReport
        fi
        echo "[$0] CIpteReport=$CIpteReport"
        # print testcase name at the top of CIpteReport file
        echo "PTE testcase: $queries" >> $CIpteReport
    else
        # print testcase name at the top of CIpteReport file
        echo "PTE testcase: $TESTCASE" >> $CIpteReport
    fi
    #### calculate overall query TPS from pteReport
    echo "[$0] testcase [$invokes] CIpteReport=$CIpteReport"
    node get_pteReport.js $pteReport
    cat $pteReport >> $CIpteReport
    rm -f $pteReport
fi

echo "[$0] $TESTCASE test completed."
