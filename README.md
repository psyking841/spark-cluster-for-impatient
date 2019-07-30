# Spark Cluster on Kubernetes for Impatient

## Contributing
If you find this repo useful here's how you can help:

* Send a pull request with your new features and bug fixes
* Help with existing issues
* Help new users with issues they may encounter
* Support the development of this image and star this repo !

## Table of Contents

  * [Description](#description)
  * [Quick Start for Impatient](#quick-start-for-impatient)
  * [More Detailed Installation Guide on Any Types Of Kubernetes Clusters](#more-detailed-installation-guide-on-any-types-of-kubernetes-clusters)
  * [Scale Your Spark Cluster](#scale-your-spark-cluster)
  * [Spark Job Example for Accessing IBM COS from Spark Cluster](#examples-to-access-ibm-cos-from-spark-cluster)

## Description

This project is meant to create and use a Spark cluster/multiple Spark clusters on top of Kubernetes **without hassles**, and enable data engineering and science working environment from local machine (e.g. your laptop). The Spark cluster created from this project currently **does not have a resources manager**. For this reason, such clusters are **for testing and running ad hoc queries/ML algorithms** purposes only. For production purposes please using [Airflow for Impatient](https://github.ibm.com/Data-Eng-and-Science-on-Kubernetes/airflow-on-k8s).

For the same reason, the Spark cluster can ONLY use **client mode**.

With scripts in this repo, you can create one cluster for each data scientist/engineer, or one cluster to be shared by them.

This Spark cluster(s) will have:

* Spark Version: 2.4.3
* Python Version: 3.7.3
* IBM Stocator library: 1.0.31-ibm-sdk
* Pre-installed Python packages (see [following section](#2-installcreate-the-cluster) for details)

This repo provides a Helm chart for creating a Spark cluster on top of Kubernetes cluster.
This project is abased on a project on [Deploying Spark on Kubernetes](https://testdriven.io/deploying-spark-on-kubernetes).

**This approach does NOT come with a resources manager like YARN, so it is NOT meant for production envrionment!**

## Quick Start for Impatient
This impatient's quick start guild is assuming you are using [IBM Cloud Container Service](https://www.ibm.com/cloud/container-service). There is "Lite plan" which is free, so go create one for yourself.
### Run in IBM Cloud:
### 1 Prerequisite
* Install IBMCLoud CLI via `curl -sL https://ibm.biz/idt-installer | bash`
* Login to your account in IBM CLI via `ibmcloud login -sso` for IBM account or `ibmcloud login -a https://cloud.ibm.com` for personal account.
* You should at least have access to the cluster in IBM Cloud (See [IBMCloud Kubernetes Service doc](https://console.bluemix.net/docs/containers/cs_cli_install.html#cs_cli_configure))

### 2 Pyspark interactive shell for impatient
```
scripts/interactive.sh # This script is NOT stable.
```

### 3 Spark-submit for impatient
**TODO**

### 4 WebUi
See [Spark-UI session](#5-spark-ui)

## Run in Minikube
* You have Minikube installed with HyperKit for OSX, KVM for Linux, see [Offical Installation Guild](https://kubernetes.io/docs/tasks/tools/install-minikube/).
* Once Minikube is installed, run
```
# For OSX
scripts/minikube-interactive-osx.sh
# For Ubuntu
scripts/minikube-interactive-linux.sh
```

## More Detailed Installation Guide on Any Types Of Kubernetes Clusters

**This requires a little little bit more patient...**

### 1 Prerequisites
* Building spark controller image under `docker/spark-controller/` folder. 
I have pre-built on for the public [here](https://hub.docker.com/r/psyking841/spark-controller).
* Building spark UI proxy image from [here](https://github.com/aseigneurin/spark-ui-proxy). 
I have pre-built one for the public [here](https://hub.docker.com/r/psyking841/spark-ui-proxy).
* Have Kubernetes and Helm clients installed (i.e. kubectl and helm)
* Have access to your cluster! (The cluster could be Minikube; or if you are using IBMCloud container service, see [IBMCloud Kubernetes Service doc](https://console.bluemix.net/docs/containers/cs_cli_install.html#cs_cli_configure)).
* Have Helm tiller server installed in your cluster so you can run Helm command! (For example, `helm init --service-account string`). **If your cluster has RBAC enabled, then you do need "service account" that allows tiller to deploy charts to your cluster!**

### 2 Install/Create the cluster

* Install dependency packages: put them under requirements.txt file.
    - See [here](docker/spark-controller/requirement.txt) for packages preinstalled in the image. 
    - To install more packages, you will have to add your package to above file then rebuild your image.
* You need to modify the values.yaml according to your need. Then run the following command.

```
helm install spark-cluster --debug --name spark-cluster-dev
```

### 3 Remove the cluster
```
helm delete spark-cluster-dev --purge
```
Note, the stuff in your Cluster Storage will be remove too!

### 4 Use the cluster

Verify your cluster is up.
```
# You need to get access to your cluster before running this. See Prerequisites.
$ kubectl get all
```

#### 4.1 Pyspark Shell

Replace the ```XXXXX``` field with what you have seen in kubectl get all command for **master pod**.

```
kubectl exec -it spark-master-controller-XXXXX pyspark
```

**If you are sharing this cluster with others, I highly recommend passing in executor number, cpu and memory to the above command, or your Spark job/SparkSession will likely take all resources from the cluster!!!**

Example:
```
kubectl exec -it spark-master-controller-XXXXX -- pyspark --driver-memory 3G --num-executors 2 --total-executor-cores 2 --executor-memory 8G
```

#### 4.2 Spark submit
Submit you Spark application  If any file or appplication need to move inisde the containers, it should be moved to shared file mount path /spark/data directory of the containers.
In this approach, you basically run a spark submit command, for details on spark-submit options see [here](https://spark.apache.org/docs/latest/submitting-applications.html)

**If you are sharing this cluster with others, I highly recommend passing in executor number, cpu and memory to the above command, or your Spark job/SparkSession will likely take all resources from the cluster!!!**

```
# Copy your Spark job code (in .jar or .py) to /spark/data folder
kubectl cp <spark-application>.jar spark-master-controller-XXXXX:/spark/data

# Execute spark-submit command
kubectl exec -it spark-master-controller-XXXXX -- bash -c 'spark-submit [spark-submit-options] /spark/data/<spark-application>.jar'
# OR
kubectl exec -it spark-master-controller-XXXXX -- bash -c 'spark-submit [spark-submit-options] /spark/data/<pysaprk-application>.py'
```

### 5 Spark UI
If Spark UI is exposed to public we do suggest enforce certain authentication.

Due to the same security concern, the URL to spark UI from this repo is by default not exposed and the Spark UI service is only exposed as cluster IP.
To access the Spark UI (when it is only exposed as ClusterIP type), using following command:

```
kubectl proxy --port 8080
```

#### 5.1 Visiting Spark mater UI
In your browser, copy paste following URL to visit the Spark WebUI (assuming you are running your cluster in "default" namespace)
```
http://localhost:8080/api/v1/namespaces/default/services/spark-ui-proxy/proxy/
```

#### 5.2 Visiting Spark job UI
You need to figure out the port, by default the UI to a Spark job is listening on 4040, but if it is taken by other jobs, Spark will take the next available port after 4040.
Trick to figure out the port to your job: click on your job from the MaterUI.

```
kubectl port-forward <spark master pod name> 4040:4040
```
Then, in your browser, use "http://localhost:4040" to access the job log.

For example:
kubectl port-forward spark-master-controller-XXXXX 4040:4040

## Scale Your Spark Cluster
```
kubectl scale –replicas=<no. of workers> rc/spark-worker-controller
```

## Examples to Access IBM COS from Spark Cluster

Access IBM COS requires [IBM Stocator lib](https://github.com/CODAIT/stocator). This library has already been in the classpath for both Spark driver and executors.

### Inteactive mode
Example to start with IBM COS bueckets under one single COS instance:
```$python
>> api_key="<your iam api key>"
>> service_endpoint="<your service endpoint>"
>> service_name="myCos"
>> cos_config = [("fs.stocator.scheme.list", "cos"), 
... ("fs.cos.impl", "com.ibm.stocator.fs.ObjectStoreFileSystem"), 
... ("fs.stocator.cos.impl", "com.ibm.stocator.fs.cos.COSAPIClient"),
... ("fs.stocator.cos.scheme", "cos"),
... ("fs.cos.{}.iam.api.key".format(service_name), api_key),
... ("fs.cos.{}.endpoint".format(service_name), service_endpoint),
... # ("fs.cos.{}.iam.service.id".format(service_name), "<your service id>"), # service id field is optional if only access buckets under a single COS instance.
... ]
>> spark.setAll(cos_config)
>> bucket_name = '<your bucket name>'
>> file_name = '<your file name>'
>> file_path = "cos://{}.{}/{}/".format(bucket_name, service_name, file_name)
>> df = spark.read.parquet(file_path)
>> df.show()
```

**To access buckets from different COS instances/regions, for each COS instance/region, you need to add a set of "iam.api.key", "endpoint", "iam.service.id" with a different service name in the `cos_config` variable. This applies to batch mode as well.**

### Batch mode
Submitting [example pyspark job](../pyspark_examples) that operates on a single IBM COS instance:
1. Copy the job file to master node
```bash
kubectl cp /path/to/example_pyspark_job.py <spark-master-pod-name>:/spark/data
```

2. Run spark-submit command
```bash
$ kubectl exec -it <spark-master-pod-name> -- bash -c \
    "spark-submit  /spark/data/example_pyspark_job.py \
    -k <your iam api key> -i <your input bucket name> -o <your output bucket name> \
    -s <you service name which could be arbitrary string> -e <bucket endpoint> \
    --input-path <your input path under bucket> --output-path <your output path under bucket>"
```
