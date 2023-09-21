pushd ../../charts/wildfly
helm dep up
popd

pushd ..
mkdir target
cd target
git clone https://github.com/wildfly/quickstart.git
cd quickstart/helloworld
mvn -B -Popenshift package wildfly:image
docker tag helloworld:latest localhost:5001/helloworld:latest
docker push localhost:5001/helloworld:latest

popd
helm install test -f ./helm.yaml ../../charts/wildfly

kubectl wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=test \
  --timeout=90s

sleep 5

curl --no-progress-meter --resolve wildfly.local:80:127.0.0.1  http://wildfly.local/HelloWorld > out
cat out | grep "Hello World"
retVal=$?
if [ $retVal -ne 0 ]; then
  echo "Unable to access the application"
  exit $retVal
fi

helm delete test