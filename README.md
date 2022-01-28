# Kubernetes Redis Queue HPA

This repo demonstrates using a Kubernetes custom metric to enable the Kubernetes Horizontal Pod Autoscaler (HPA) to scale based on redis queue (rq) length plus busy worker count.

**NOTE**: If you want to scale on CPU and/or memory, there's no need for this repo or all this complexity. Use the [Metrics Server](https://github.com/kubernetes-sigs/metrics-server#use-cases) instead.

# Installing with helm

```shell
helm install suihei . -n YOUR_NAMESPACE_HERE --create-namespace -f values.yaml -f values-custom.yaml -f values-custom-secret.yaml
```

# Uninstalling with helm

```shell
helm uninstall suihei
```

# Kubernetes custom metrics

- List all metric definitions:

  ```shell
  kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/" | jq .
  ```

  Sample output:
  ```json
  {
    "kind": "APIResourceList",
    "apiVersion": "v1",
    "groupVersion": "custom.metrics.k8s.io/v1beta1",
    "resources": [
      {
        "name": "deployments.apps/redisqueue_length",
        "singularName": "",
        "namespaced": false,
        "kind": "MetricValueList",
        "verbs": ["get"]
      }
    ]
  }
  ```
- Get metric values for one metric

  ```shell
  namespace=YOUR_NAMESPACE_HERE
  kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/$namespace/deployments.apps/rq-worker/redisqueue_length?metricLabelSelector=queues%3Dhigh-low-someinvalidqueuename" | jq .
  ```

  Sample output:
  ```json
  {
    "apiVersion": "custom.metrics.k8s.io/v1beta1",
    "items": [
      {
        "_debug": {
          "queue_info": {
            "high": {
              "busy_workers": 5,
              "queued_jobs": 3
            },
            "low": {
              "busy_workers": 2,
              "queued_jobs": 0
            },
            "someinvalidqueuename": {
              "error": "queue not found"
            }
          }
        },
        "describedObject": {
          "apiVersion": "apps/v1",
          "kind": "Deployment",
          "name": "rq-worker",
          "namespace": "YOUR_NAMESPACE_HERE"
        },
        "metricName": "count",
        "timestamp": "2022-01-28T11:40:42Z",
        "value": "10"
      }
    ],
    "kind": "MetricValueList",
    "metadata": {
      "selflink": "/apis/custom.metrics.k8s.io/v1beta1/"
    }
  }
  ```

# Ports

- `32000`: apiserver (see [`apiserver.yaml`](/templates/apiserver.yaml))
- `36379`: Redis server (see [`redis-server.yaml`](/templates/redis-server.yaml))

# URLs

Use `ip="$(minikube ip)"` to get the IP address of the cluster.

- Enqueue job:

  ```shell
  queue=high
  curl -XPOST \
    -H 'Content-Type: application/json' \
    -d '{"sleep": 60}' \
    "http://$ip:32000/queues/$queue/enqueue"
  ```

  Sample output:
  ```json
  {
    "job": {
      "id": "uuiduuid-uuid-4uid-uuid-uuiduuiduuid", 
      "result": null, 
      "status": "queued"
    }
  }
  ```

# Troubleshooting

Check the metrics API service is working:

```shell
kubectl get apiservice | grep custom.metrics
```
```
v1beta1.custom.metrics.k8s.io  YOUR_NAMESPACE_HERE/custom-metrics-apiserver  True  1h
```

If kubernetes won't allow helm to reinstall the app due to lingering objects after an uninstall, use the following:

```shell
kubectl proxy &  # get a proxy listening on port 8001.
namespace=YOUR_NAMESPACE_HERE
curl -k \
  -XPUT \
  -H "Content-Type: application/json" \
  --data-binary '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"'"$namespace"'"},"spec":{"finalizers":[]}}' \
  "http://127.0.0.1:8001/api/v1/namespaces/$namespace/finalize"
```

# License

See [`LICENSE`](/LICENSE) and [`licensing.md`](/licensing.md) for details.
