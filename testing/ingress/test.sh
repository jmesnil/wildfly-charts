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
helm install test -f ./with-ingress.yaml ../../charts/wildfly

kubectl wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=test \
  --timeout=90s

sleep 5

echo Test Ingress access without TLS

curl --no-progress-meter --resolve wildfly.local:80:127.0.0.1  http://wildfly.local/HelloWorld > out
cat out | grep "Hello World"
retVal=$?
if [ $retVal -ne 0 ]; then
  echo "Unable to access the application"
  exit $retVal
fi

echo Test Ingress access with TLS

pushd ../target/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=wildfly.local"
kubectl create secret tls test-secret-tls --key="tls.key" --cert="tls.crt"
popd 

helm upgrade test -f ./with-tls-ingress.yaml ../../charts/wildfly
sleep 5

curl -k --no-progress-meter --resolve wildfly.local:443:127.0.0.1  https://wildfly.local/HelloWorld > out
cat out | grep "Hello World"
retVal=$?
if [ $retVal -ne 0 ]; then
  echo "Unable to access the application"
  exit $retVal
fi


helm delete test