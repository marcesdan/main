### Tabla de contenidos

- [Notes-app](#notes-app)
- [Crear una imagen de Docker para la app](#crear-una-imagen-de-docker-para-la-app)
- [Ejecutar la app en un contenedor](#ejecutar-la-app-en-un-contenedor)
- [Subir la imagen a Docker Hub](#subir-la-imagen-a-docker-hub)
- [Subir a EKS](#subir-a-eks)
  - [Requisitos](#requisitos)
- [Desplegar la app](#desplegar-la-app)
  - [Escalado imperativo](#escalado-imperativo)
  - [Limitar uso de recursos](#limitar-uso-de-recursos)
- [Bajar los recursos](#bajar-los-recursos)

## Notes-app

App de ejemplo similar a [Evernote](https://evernote.com/) y [Google Keep](https://www.google.com/keep/).

La app permite:

1. Escribir notas
2. Adjuntar imágenes a las notas.

Las notas no se pierden si la app se reinicia. Las notas se almacenan en una base de datos MongoDB. Y se usa Multer para guardar las imágenes subidas.

## Crear una imagen de Docker para la app

Instalar Docker Community Edition (CE).

Siguiendo las instrucciones de la [documentación oficial](https://docs.docker.com/install/).

Con el siguiente comando se construye una imagen de Docker de la app:

```docker
docker build -t notes-app .
```

Debería verse la imagen `notes-app`

## Ejecutar la app en un contenedor

La app requiere una base de datos MongoDB para funcionar.

**Pero primero debemos crear una red de docker para comunicar la app con mongo y minio.**

Para eso necesitamos una [network de Docker](https://docs.docker.com/network/).

```terminal
docker network create notes-app
```

**Para correr mongo:**

```docker
docker run \
  --name=mongo \
  --rm \
  --network=notes-app mongo
```

- `--name` define un nombre para el contenedor
- `--rm` automáticamente limpia el contenedor y remueve el sistema de archivos cuando el contenedor se detiene.
- `--network` representa la red de Docker en la que el contenedor debe ejecutarse.
- `mongo` es el nombre de la imagen de Docker que se ejecutará.

MongoDB ahora se está ejecutando en un contenedor de Docker.

**Para correr minio:**

```docker
docker run \
  --name minio \
  --network=mynetwork \
  -p 9000:9000 \
  -e "MINIO_ROOT_USER=mykey" -e "MINIO_ROOT_PASSWORD=mysecret" \
  minio/minio server /data
```

**Ahora podemos ejecutar la app en un contenedor de Docker.**

```docker
docker run \
  --name=notes-app \
  --rm \
  --network=notes-app \
  -p 3000:3000 \
  -e MONGO_URL=mongodb://mongo:27017/dev \
  notes-app
```

- `--name` define un nombre para el contenedor
- `--rm` automáticamente limpia el contenedor y remueve el sistema de archivos cuando el contenedor se detiene.
- `--network` representa la red de Docker en la que el contenedor debe ejecutarse.
- `-p 3000:3000` publica el puerto 3000 del contenedor en el puerto 3000 de la máquina local.
- `-e` establece una variable de entorno dentro del contenedor.

La app lee la URL del servidor de MongoDB de la variable de entorno `MONGO_URL`.

Puede observarse que el host es `mongo` y no una dirección IP. Dado que `mongo` es el nombre que se le dió al contenedor de MongoDB con la bandera `--name=mongo`.

**Los contenedores en la misma red de Docker pueden comunicarse entre sí por su nombre.**

Esto es posible gracias a un mecanismo DNS incorporado.

Ahora deberían verse dos contenedores ejecutándose en la terminal, `notes-app` y `mongo`

```docker
docker ps
CONTAINER ID    IMAGE       COMMAND                  PORTS                    NAMES
2fc0a10bf0f1    notes-app   "node index.js"          0.0.0.0:3001->3000/tcp   notes-app
41b50740a920    mongo       "docker-entrypoint.s…"   27017/tcp                mongo
9dea6fe8c33a    minio/minio "/usr/bin/docker-ent…"   0.0.0.0:9000->9000/tcp   minio
```

Debería verse la app en <http://localhost:3000>.

Para parar y eliminar los contenedores, ejecutar:

```terminal
docker stop mongo notes-app
docker rm mongo notes-app
```

## Subir la imagen a Docker Hub

**Primero, crear un [Docker ID](https://hub.docker.com/signup).**

Una vez que tengas tu Docker ID, debes autorizar a Docker para que se conecte a la cuenta de Docker Hub:

```terminal
docker login
```

**Las imágenes subidas a Docker Hub deben tener un nombre de la forma `username/image:tag`:**

para renombrar la imagen, ejecutar::

```terminal
docker tag notes-app <username>/notes-app-js:1.0.0
```

- `username` es tu Docker ID.
- `image` es el nombre de la imágen.
- `tag` es un atributo adicional opcional, se usa para indicar la versión de la imágen.

Con esto, es posible subir la imagen a Docker Hub

```terminal
docker push <username>/notes-app-js:1.0.0
```

La imagen ahora está disponible en Docker Hub como `<username>/notes-app-js:1.0.0`, y cualquiera puede descargarla y ejecutarla en su máquina.

Puede encontrarse en <https://hub.docker.com/repository/docker/marcesdan/notes-app-js>

Puede probarse descargando la imagen y ejecutándola en un contenedor (teniendo mongo y minio corriendo)

```docker
docker run \
  --name=notes-app \
  --rm \
  --network=notes-app \
  -p 3000:3000 \
  -e MONGO_URL=mongodb://mongo:27017/dev \
  <username>/notes-app-js:1.0.0
```

## Subir a EKS

> **Aviso:** AWS no es gratis, y los recursos que creará en esta sección producirán cargos bastante altos en su tarjeta de crédito.

### Requisitos

- [aws account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
- [aws access key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys)
- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [eksctl](https://eksctl.io/installation/)

Con `ekctl` instalado, podemos crear un cluster de EKS con el siguiente comando

```terminal
eksctl create cluster --region=us-east-1 --name=notes
```

El comando crea un cluster de Kubernetes con las siguientes propiedades

- Dos nodos de trabajo (este es el valor predeterminado)
- Los nodos de trabajo son instancias de Amazon EC2 [`m5.large`](https://aws.amazon.com/ec2/instance-types/) (este es el valor predeterminado)
- El cluster se crea en la región `us-east-1` (este es el valor predeterminado)
- El nombre del cluster es `notes`

El comnado puede tardar unos 15 minutos en completarse.

Una vez que el comando se completa, puedes verificar que el cluster se creó correctamente con:

```terminal
kubectl get nodes
NAME                                           STATUS   ROLES    AGE   VERSION
ip-192-168-25-57.us-east-1.compute.internal    Ready    <none>   23m   v1.12.7
ip-192-168-68-152.us-east-1.compute.internal   Ready    <none>   23m   v1.12.7
```

> Nótese que no es posible listar o inspeccionar los nodos maestros de ninguna manera con Amazon EKS. AWS administra completamente los nodos maestros, y no es necesario preocuparse por ellos.

Dado que los nodos de trabajo son instancias de Amazon EC2, puedes inspeccionarlos en la [Consola de AWS EC2](https://us-east-1.console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances).

También es posible inspeccionar el recurso Amazon EKS en su cuenta de AWS en la [Consola de AWS EKS](https://us-east-1.console.aws.amazon.com/eks/home?region=us-east-1#/clusters).

> ekctl crea también un [stack de CloudFormation](https://us-east-1.console.aws.amazon.com/cloudformation/home) con todos los recursos que pertenecen al cluster de Amazon EKS.

**El cluster de Amazon EKS está listo para usar.**

## Desplegar la app

El código contiene también las definiciones YAML de Kubernetes para los despliegues y servicios.

```terminal
kube/
├── notes.yaml
├── minio.yaml
└── mongo.yaml
```

Para desplegar la app en el cluster de Amazon EKS

```terminal
kubectl apply -f kube
```

Para observar el estado de los Pods

```terminal
kubectl get pods --watch
```

La app debería estar ejecutándose en unos minutos. Para acceder a la app, necesitas la dirección pública del servicio `notes`.

Para obtener la dirección pública del servicio `notes`

```terminal
kubectl get service notes
NAME  TYPE         CLUSTER-IP    EXTERNAL-IP                        PORT(S)
notes LoadBalancer 10.100.188.43 <xxx.us-east-1.elb.amazonaws.com>  80:31373/TCP
```

La columna `EXTERNAL-IP` debería contener un nombre de dominio fully-qualified. Con la cual acceder a la app desde cualquier lugar.

> Note que puede tomar un par de minutos hasta que la resolución DNS de AWS esté configurada. Si obtienes un error `ERR_NAME_NOT_RESOLVED`, intenta nuevamente en unos minutos.

### Escalado imperativo

Para escalar la app a 10 réplicas

```terminal
kubectl scale --replicas=10 deployment notes
```

### Limitar uso de recursos

Ahora mismo el número de pods que se pueden ejecutar en el cluster es ilimitado.

En Amazon EKS, estos límites dependen del tipo de instancia EC2 que selecciones.

**Las instancias más grandes pueden alojar más Pods que las más pequeñas.**

Esto esta documentado en [`eni-max-pods.txt`](https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt)

La instancia EC2 `m5.large` que estamos usando puede alojar hasta 29 Pods.

Y tenemos dos nodos de trabajo en el cluster, con lo cual podemos alojar hasta 58 Pods en el cluster.

Entonces las réplicas que excedan el límite de 58 Pods deberían quedar colgadas en el estado _Pending_. Porque ningún nodo podría ejecutarlas.

Para probar, verificar cuántos pods están ejecutándose

```terminal
kubectl get pods --all-namespaces
```

Deberías poder ver 9 Pods - los 3 que forman la aplicacion (`minio`, `mongo` y `notes`) y 6 Pods de sistema.

> Kubernetes ejecuta algunos Pods del sistema en los nodos de trabajo en el espacio de nombres `kube-system`. Estos Pods también cuentan para el límite. La bandera `--all-namespaces` muestra los Pods de todos los espacios de nombres del cluster.

Entonces, ¿cuántas réplicas del Pod `notes` puedes ejecutar en el cluster?

Si 58 es el número máximo de Pods que pueden ejecutarse en el cluster.

Y tenemos:

- 6 Pods de sistema
- 1 Pod para `minio`
- 1 Pod para `mongo`

Entonces, podemos ejecutar hasta 50 réplicas del Pod `notes` en el cluster.

Vamos a exceder este límite a propósito para observar qué sucede.

Para escalar la app a 60 réplicas

```terminal
kubectl scale --replicas=60 deployment/notes
```

Esperar a que los Pods se inicien.

Si calculamos bien, solo 50 de estas 60 réplicas deberían estar ejecutándose en el cluster - las 10 restantes deberían estar colgadas en el estado _Pending_. Porque no hay suficientes nodos de trabajo para ejecutarlas.

Para contar los Pods que están ejecutándose y los que están colgados en el estado _Pending_, podemos usar el comando `kubectl get pods` con la bandera `--field-selector`.

```terminal
kubectl get pods \
  -l app=notes \
  --field-selector='status.phase=Running' \
  --no-headers | wc -l
```

La salida del comando debería ser 50

Y ahora con el estado _Pending_:

```terminal
kubectl get pods \
  -l app=notes \
  --field-selector='status.phase=Pending' \
  --no-headers | wc -l
```

La salida del comando debería ser 10

Si calculamos bien, 50 de las 60 réplicas deberían estar ejecutándose en el cluster - las 10 restantes deberían estar colgadas en el estado _Pending_. Porque no hay suficientes nodos de trabajo para ejecutarlas.

Podemos verificar que solo hay 50 Pods ejecutándose en el cluster con:

```terminal
kubectl get pods \
  --all-namespaces \
  --field-selector='status.phase=Running' \
  --no-headers | wc -l
```

La salida del comando debería ser 58

Para arreglar el problema, podemos escalar el número de réplicas a 50.

```terminal
kubectl scale --replicas=50 deployment/notes
```

Luego de un rato, deberías ver que todos los Pods están ejecutándose.

Para correr un número más alto de réplicas, necesitaríamos:

- Más nodos de trabajo en el cluster.

> Kubernetes no tiene límites en el número de Pods que puede ejecutar, puede correr [cientos de Pods](https://kubernetes.io/docs/setup/best-practices/cluster-large/)

- o bien usar instancias EC2 más grandes que puedan alojar más Pods, [ver límites](https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt)

Por ejemplo si usamos instancias EC2 `m5.24xlarge` para los nodos de trabajo, podríamos alojar hasta 737 Pods en cada uno.

## Bajar los recursos

Para limpiar los recursos de esta demo, ejecutar

```terminal
eksctl delete cluster --region=us-east-1 --name=notes
```

Una vez que el comando se completa, puedes verificar que el cluster se eliminó correctamente en la consola de AWS EKS.

- [Consola de EKS](https://console.aws.amazon.com/eks/home)
- [Consola de EC2](https://console.aws.amazon.com/ec2/v2/home?#Instances)

> Cuando eliminas un cluster de Amazon EKS, el stack de CloudFormation que contiene los recursos de AWS que pertenecen al cluster también se elimina.

> Verificar también la región correcta en la consola de AWS en la que se creó el cluster.
