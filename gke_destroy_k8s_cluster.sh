#!/bin/bash
#========================================================================
#
# FILE:         gke_destroy_k8s_cluster.sh
#
# USAGE:        gke_destroy_k8s_cluster.sh -p <project_id> <cluster_name>
#
# DESCRIPTION:  Destroy a Google Kubernetes Engine cluster, its associated project, and gcp configuration named "k8s"
#
# OPTIONS:      -p specify the project ID in which the cluster was created 
#               -a specify the GCP account for authentication
# ARGUMENTS:    cluster name (required)
# AUTHOR:       Tuan Hoang
# VERSION:      1.0.0
# CREATED:      18-Sept-2021
#========================================================================
script_name=${0##*/}
function usage()
{
    echo "Syntax help: $script_name -p <project_id> <cluster_name>"
}

function die()
{
    echo "$1" && exit $2
}
# Destroy a K8s cluster
# destroy_k8s_cluster.sh -p <project_id> <cluster-name> 

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

# destroy_cluster <CLUSTER_NAME> <PROJECT_ID>
function destroy_cluster()
{
    gcloud container clusters delete "$1" && \
    gcloud services disable container.googleapis.com && \
    gcloud alpha billing accounts projects unlink "$2" && \
    gcloud projects delete "$2" && \
    gcloud config configurations activate default && \
    gcloud config configurations delete k8s || \
    return 1
}

# Check if "gcloud" binary has been installed
if binary_exist "gcloud"; then
    echo "Found gcloud binary. Continue..."
else
    echo "Not found gcloud binary. Stop..."
    exit 1
fi

while getopts "p:a:h" opt; do
    case $opt in
        p)
            project_id=${OPTARG}
            ;;
        a)
            account=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            die "Unknown option(s) given" 1
            ;;
    esac
done
shift $((  OPTIND - 1 ))
cluster_name="$1"

# Check if user is authenticated with GCP
if  ! (gcloud auth list | grep "ACTIVE  ACCOUNT") > /dev/null 2>&1 ; then
    echo "You must login to GCP to continue" && gcloud auth login "$account" || \
    die "Cannot authenticate with the account $account" 1
fi

if ! destroy_cluster "$cluster_name" "$project_id"; then
    die "Failed to destroy the cluster $cluster_name on the project $project_id" 1
else 
    die "The cluster $cluster_name has been successfully destroyed" 0
fi
