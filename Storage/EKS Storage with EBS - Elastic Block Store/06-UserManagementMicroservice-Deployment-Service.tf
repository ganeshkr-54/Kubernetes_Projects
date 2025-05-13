apiVersion: apps/v1
kind: Deployment 
metadata:
  name: usermgmt-microservice
  labels:
    app: usermgmt-restapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: usermgmt-restapp
  template:  
    metadata:
      labels: 
        app: usermgmt-restapp
    spec:
      containers:
        - name: usermgmt-restapp
          image: stacksimplify/kube-usermanagement-microservice:1.0.0
          ports: 
            - containerPort: 8095 
      initContainers:
        - name: init-mysql
          image: busybox:1.28
          command: ['sh', '-c', "until nslookup mysql; do echo waiting for mysqlservice; sleep 2; done"]
          
          env:
            - name: DB_HOSTNAME
              value: "mysql"            
            - name: DB_PORT
              value: "3306"            
            - name: DB_NAME
              value: "usermgmt"            
            - name: DB_USERNAME
              value: "root"            
            - name: DB_PASSWORD
              value: "dbpassword11"            
