#!/bin/bash
#========================================================================
#
# FILE:         gke_create_k8s_cluster.sh
#
# USAGE:        gke_create_k8s_cluster.sh -a <account> -b <billing_account> -r <region> -z <zone> <cluster_name> [num_nodes] [machine_type]
#
# DESCRIPTION:  Create a Google Kubernetes Engine cluster under a new project, new gcp configuration named "k8s"
#
# OPTIONS:      -a specify the GCP account for authentication
#               -r specify the region of the cluster
#               -z specify the zone of the cluster
#               -b specify the billing account to link the new project created for the cluster
# ARGUMENTS:    cluster name (required)
#               num_nodes (optional, number of cluster worker nodes)
#               machine_type (optional, the machine type of underlying compute instance node)
# AUTHOR:       Tuan Hoang
# VERSION:      1.0.0
# CREATED:      18-Sept-2021
#========================================================================
script_name=${0##*/}
function usage()
{
    echo "Syntax help: $script_name -a <account> -b <billing_account> -r <region> -z <zone> <cluster_name> <num_nodes> <machine_type>"
    echo "You must specify at least account, billing account, region, zone options and the cluster name"
}

function die()
{
    echo "$1" && exit $2
}

# binary_exist <BINARY_NAME>
function binary_exist()
{
    local IFS=:
    for path in $PATH
    do
        bin_path=$path"/$1"
        if [[ -x "$bin_path" ]]; then 
            return 0
        fi
    done
    return 1
}

# create_project <PROJECT_ID> <PROJECT_NAME>
function create_project()
{
    if  gcloud projects create "$1" --name "$2"; then
        return 0
    fi
    return 1
}

# create GCP configuration named "k8s" if not exists
function create_k8s_gcp_configuration()
{
    if  ! gcloud config configurations describe k8s > /dev/null 2>&1; then
        gcloud config configurations create k8s && return 0 || return 1
    fi
    return 0
}

# configure_project <REGION> <ZONE> <PROJECT_ID> <ACCOUNT> <BILLING_ACCOUNT>
function configure_project()
{
    create_k8s_gcp_configuration && \
    gcloud config configurations activate k8s && \
    gcloud auth login "$4" && \
    gcloud config set project "$3" && \
    gcloud config set compute/zone "$2" && \
    gcloud config set compute/region "$1" && \
    gcloud alpha billing accounts projects link "$3" --billing-account "$5" && \
    gcloud services enable compute.googleapis.com && \
    gcloud services enable cloudapis.googleapis.com && \
    gcloud services enable container.googleapis.com || \
    return 1
}

# create_cluster <CLUSTER-NAME> <NUMBER-OF-NODES> <MACHINE-TYPE>
function create_cluster()
{
    gcloud container clusters create "$1" --num-nodes $2 --machine-type "$3" && \
    gcloud container clusters get-credentials "$1" && return 0 || \
    return 1
}

# Check if "gcloud" binary has been installed
if ! binary_exist "gcloud"; then
    die "Not found gcloud binary. Stop..." 1
fi

project_id="tuanha-aphrodite-"$(date +%y%m%d%H%M%S)
project_name="$project_id"
while getopts "r:z:a:b:h" opt; do
    case $opt in
        r)
            region=${OPTARG}
            ;;
        z)
            zone=${OPTARG}
            ;;
        a)
            account=${OPTARG}
            ;;
        b)
            billing_account=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            die "Unknown option(s) given" 1
            ;;
    esac
done
shift $((  OPTIND - 1 ))

if [[ -z "$1" || -z "$region" || -z "$zone" || -z "$account" || -z "$billing_account" ]]; then
    usage
    exit 1
fi

cluster_name="$1"

# Check if user is authenticated with GCP
if  ! (gcloud auth list | grep "ACTIVE  ACCOUNT") > /dev/null 2>&1 ; then
    echo "You must login to GCP to continue" && gcloud auth login "$account" || \
    die "Cannot authenticate with the account $account" 1
fi

if ! create_project "$project_id" "$project_name"; then
    die "Failed to create a GCP project" 1
fi

if ! configure_project "$region" "$zone" "$project_id" "$account" "$billing_account"; then
    die "Failed to configure the project" 1
fi

num_nodes=${2:-2}
machine_type=${3:-"n1-standard-1"}
if ! create_cluster "$cluster_name" "$num_nodes" "$machine_type" ; then
    die "Failed to create the cluster $1" 1
else 
    die "The cluster $cluster_name has been successfully created" 0
fi