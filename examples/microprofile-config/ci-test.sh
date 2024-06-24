helm install ${APP} -f ${YAML_FILE} ../../charts/wildfly

# Wait until the deployment is rolled out...
oc rollout status -w --timeout=10m deployment ${APP}
# ... and a bit more
sleep 30

# Check that the application is up and running
# and is using the config property from the Chart configuration
URL=$(oc get route ${APP} -o jsonpath="{.spec.host}")
MSG=$(curl -s https://${URL}/config/value)
expected="Hello from OpenShift"
if [ "${MSG}" != "${expected}" ] ;then
  echo "Expected: '${expected}, got: '${MSG}'"
  helm delete ${APP}
  exit 1
fi

helm delete ${APP}
