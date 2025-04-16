

# Deployment Strategies

Deployment Strategies helps to implement upgrades with no downtime. 

There are 3 types of Strategies:
1. Rolling Updates
2. Canary Deployment
3. Blue & Green Deployment

## Rolling Updates:

- While upgrading any deployment it will first create one new pod with new version and delete pod with old version, so that there wont be any downtime to the application.
- Max Surge and Max Unavailability are parameters to define no:of new pods to increase with new version and no:of pods that can be deleted without effecting application.

![Alt Text](https://www.bluematador.com/hs-fs/hubfs/blog/new/Kubernetes%20Deployments%20-%20Rolling%20Update%20Configuration/Kubernetes-Deployments-Rolling-Update-Configuration.gif?width=1600&name=Kubernetes-Deployments-Rolling-Update-Configuration.gif)


## Canary Deployment:

- Even though we test deployments in test, qual, pre-prod environments but cluster configurations, data is mostly different. That's why we still get many errors in prod env which are not encounted in previous environments.
- However in Canary deployment we will be testing user traffic in production environment itself by routing limited user traffic to newer version pods and after validating and confirmation of no issues then 100% traffic can be routed to newer pods.

![Alt Text](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*VzvqBTvvt4XvVJZYwSW9aQ.png)

Steps:
1. Ingress Nginx Has the ability to handle canary routing by setting specific annotations, the following is an example of how to configure a canary deployment with weighted canary routing.

Let's install ingress controller using helm

```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

```

Create Production deployment and service¶
This is the main deployment of your application with the service that will be used to route to it




```bash
echo "
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production
  labels:
    app: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: production
  template:
    metadata:
      labels:
        app: production
    spec:
      containers:
      - name: production
        image: registry.k8s.io/ingress-nginx/e2e-test-echo:v1.1.2@sha256:b43ed89fb7ae67c430470d4eb9ea4058c1c74c42b10aa064244eb971b9a370d8
        ports:
        - containerPort: 80
        env:
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: production
  labels:
    app: production
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: production
" | kubectl apply -f -

```

Create the canary deployment and service¶
This is the canary deployment that will take a weighted amount of requests instead of the main deployment

```bash
echo "
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
  labels:
    app: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary
  template:
    metadata:
      labels:
        app: canary
    spec:
      containers:
      - name: canary
        image: registry.k8s.io/ingress-nginx/e2e-test-echo:v1.1.2@sha256:b43ed89fb7ae67c430470d4eb9ea4058c1c74c42b10aa064244eb971b9a370d8
        ports:
        - containerPort: 80
        env:
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: canary
  labels:
    app: canary
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: canary
" | kubectl apply -f -


```

Create Ingress Pointing To Your Main Deployment¶
Next you will need to expose your main deployment with an ingress resource, note there are no canary specific annotations on this ingress
```bash
echo "
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production
  annotations:
spec:
  ingressClassName: nginx
  rules:
  - host: echo.prod.mydomain.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: production
            port:
              number: 80
" | kubectl apply -f -
```

Create Ingress Pointing To Your Canary Deployment¶
You will then create an Ingress that has the canary specific configuration, please pay special notice of the following:

The host name is identical to the main ingress host name
The nginx.ingress.kubernetes.io/canary: "true" annotation is required and defines this as a canary annotation (if you do not have this the Ingresses will clash)
The nginx.ingress.kubernetes.io/canary-weight: "50" annotation dictates the weight of the routing, in this case there is a "50%" chance a request will hit the canary deployment over the main deployment

```bash
echo "
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary
  annotations:
    nginx.ingress.kubernetes.io/canary: \"true\"
    nginx.ingress.kubernetes.io/canary-weight: \"50\"
spec:
  ingressClassName: nginx
  rules:
  - host: echo.prod.mydomain.com
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: canary
            port:
              number: 80
" | kubectl apply -f -
```

Testing your setup¶
You can use the following command to test your setup (replacing INGRESS_CONTROLLER_IP with your ingresse controllers IP Address)

```bash
for i in $(seq 1 10); do curl -s --resolve echo.prod.mydomain.com:80:$INGRESS_CONTROLLER_IP echo.prod.mydomain.com  | grep "Hostname"; done
```
You will get the following output showing that your canary setup is working as expected:

![image](https://github.com/user-attachments/assets/6cd5b96e-0c4a-4f35-82f4-e6d136067b3b)

Resources:
[Canary Deployment Steps](https://kubernetes.github.io/ingress-nginx/examples/canary/)
