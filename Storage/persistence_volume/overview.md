***Volume Provisioning Using Storage Class***

✨ Local volumes are similar to HostPath, but they persist across pod restarts and node restarts. In that sense they are **Persistent Volumes.**

🎯 **Storage Class**

  👉 We need to define a **storage class** for using local volumes, storage class use provisioners to allocate space to pods.
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

```
# Create storage class
k create -f local-storage-class.yaml
```

🎯 **Persistent Volume**

 👉 Now we will create a **persistent volume** using the storage class that will persist even after pod restarts.

🥕  First, we need to create a backing directory “/mnt/disks/disk-1” inside the node.

```yaml
#create this directory on the node you deploy the pod

ssh node02

mkdir -p /mnt/disks/disk-1
# exit from the node
```

🥕 Now, we can create a local volume backed by the “/mnt/disks/disk1” directory

```
apiVersion: v1 
kind: PersistentVolume
metadata:
  name: local-pv
  labels:
    release: stage
spec:
  volumeMode: Filesystem
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  persistentVolumeReclaimPolicy: Delete
  local:
    path: /mnt/disks/disk-1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname  # This is a built-in node label automatically assigned by Kubernetes to every node — it holds the node’s name.
              operator: In 
              values:
                - node02  # change according to your node name

# apply the config file

```

```
kubectl get pvc
```
🎯 **Persistent Volume Claims**

  👉 When containers want access to some persistent storage they make a claim (or rather, the developer and cluster administrator coordinate on necessary storage resources to claim).

  🥕 Kubernetes always tries to match the smallest volume that can satisfy a claim.

  🥕 It’s important to realize that claims don’t mention volumes by name. You can’t claim
specific volume. The matching is done by Kubernetes based on storage class, capacity, 
and labels.
🥕 Persistent volume claims belong to a namespace, all the pods that mount the persisten           
volume claim must be from that claim’s namespace.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-storage-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: local-storage
  selector:
    matchLabels:
     release: stage
```
```
kubectl get pvc
````

🎯 **Mounting Claims as Volume**

👉 We have provisioned a volume and claimed it. It’s time to use the claimed storage in a container.

🥕 First, the persistent volume claim must be used as a volume in the pod and then the containers in the pod can mount it.

🥕 The key is in the persistentVolumeClaim. The claim uniquely identifies within the current namespace and makes it available as a volume. Then, the container can refer to it by its name and mount it to "/mnt/data”

🥕 Before we create the pod it’s important to note that the persistent volume claim didn’t    actually claim any storage yet and **pvc status** would be in pending state. ( kubectl get pvc)

🥕 Apply the pod config file, then claim will be bound to the pod.

```
apiVersion: v1
kind: Pod
metadata:
  name: the-pod
spec:
  containers:
    - name: the-container
      image: nginx
      volumeMounts:
        - mountPath: /mnt/disks
          name: persistent-volume
  volumes:
    - name: persistent-volume
      persistentVolumeClaim:
        claimName: local-storage-claim
  nodeName: node02

```
