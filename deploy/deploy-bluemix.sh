#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.bluemixrc

#################################################################################
# Pull Dockerhub images
#################################################################################

echo "Looking up Bluemix registry images"
BLUEMIX_IMAGES=$(bluemix ic images --format "{{.Repository}}:{{.Tag}}")

REQUIRED_IMAGES=(
    ${HELLO_LIBERTY_V1_IMAGE}
    ${HELLO_LIBERTY_V2_IMAGE}
    ${GATEWAY_IMAGE}
)

for image in ${REQUIRED_IMAGES[@]}; do
    echo $BLUEMIX_IMAGES | grep $image > /dev/null
    if [ $? -ne 0 ]; then
        echo "Pulling ${DOCKERHUB_NAMESPACE}/$image from Dockerhub"
        bluemix ic cpi ${DOCKERHUB_NAMESPACE}/$image ${BLUEMIX_REGISTRY_HOST}/${BLUEMIX_REGISTRY_NAMESPACE}/$image
    fi
done

#################################################################################
# Fetch registry credentials
#################################################################################

if [ "$ENABLE_SERVICEDISCOVERY" = true ]; then
    SDKEY=$(cf service-key sd sdkey | tail -n +3)
    REGISTRY_URL=$(echo "$SDKEY" | jq -r '.url')
    REGISTRY_TOKEN=$(echo "$SDKEY" | jq -r '.auth_token')
else
    # TODO: Use local registry credentials
    echo "Using environment vars for registry"
    if [-z $A8_REGISTRY_URL || -z $A8_REGISTRY_TOKEN ]; then
	echo "Please set REGISTRY_URL and REGISTRY_TOKEN before continuing"
 	exit 1
    fi
   
fi

   
#################################################################################
# Start the microservice instances
#################################################################################

echo "Starting helloliberty microservice (v1)"

bluemix ic group-create --name helloliberty1 \
  --publish 9080 --memory 256 --auto \
  --min 1 --max 2 --desired 1 \
  --env A8_REGISTRY_URL=$A8_REGISTRY_URL \
  --env A8_REGISTRY_TOKEN=$A8_REGISTRY_TOKEN \
  --env A8_SERVICE=helloliberty:v1 \
  --env A8_ENDPOINT_PORT=9080 \
  --env A8_LOG=false \
  ${BLUEMIX_REGISTRY_HOST}/${BLUEMIX_REGISTRY_NAMESPACE}/${HELLO_LIBERTY_V1_IMAGE}

echo "Starting helloliberty microservice (v2)"


bluemix ic group-create --name helloliberty2 \
  --publish 9080 --memory 256 --auto \
  --min 1 --max 2 --desired 1 \
  --env A8_REGISTRY_URL=$A8_REGISTRY_URL \
  --env A8_REGISTRY_TOKEN=$A8_REGISTRY_TOKEN \
  --env A8_SERVICE=helloliberty:v2 \
  --env A8_ENDPOINT_PORT=9080 \
  --env A8_LOG=false \
  ${BLUEMIX_REGISTRY_HOST}/${BLUEMIX_REGISTRY_NAMESPACE}/${HELLO_LIBERTY_V2_IMAGE}

echo "Starting helloliberty microservice (v2)"

   
#################################################################################
# Start the gateway
#################################################################################
bx ic groups | grep gateway > /dev/null
if [ $? -ne 0 ]; then
	echo "Starting gateway"
	bluemix ic group-create --name helloliberty_gateway \
  	--publish 6379 --memory 256 --auto \
  	--min 1 --max 2 --desired 1 \
	--hostname $HELLO_LIBERTY_HOSTNAME \
  	--domain $ROUTES_DOMAIN \
  	--env A8_CONTROLLER_URL=$A8_CONTROLLER_URL \
  	--env A8_TENANT_TOKEN=$A8_TENANT_TOKEN \
  	--env A8_SERVICE=gateway \
	--env A8_CONTROLLER_POLL=5s \
  	--env A8_LOG=false \
	--env A8_REGISTER=false \
  	${BLUEMIX_REGISTRY_HOST}/${BLUEMIX_REGISTRY_NAMESPACE}/${GATEWAY_IMAGE}

fi
