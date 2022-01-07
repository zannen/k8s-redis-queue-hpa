# Kubernetes Redis Queue HPA

This repo demonstrates using a Kubernetes custom metric, whose values are fetched via Prometheus, to enable the Kubernetes Horizontal Pod Autoscaler (HPA) to scale based on redis queue (rq) length.

**NOTE**: If you want to scale on CPU and/or memory, there's no need for this repo or all this complexity. Use the [Metrics Server](https://github.com/kubernetes-sigs/metrics-server#use-cases) instead.

# Installing with helm

```shell
helm install suihei .
```

# Uninstalling with helm

```shell
helm uninstall suihei
```

# Kubernetes custom metrics

- List all metric definitions:

  ```shell
  kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
  ```

  Sample output:
  ```json
  {
    "kind": "APIResourceList",
    "apiVersion": "v1",
    "groupVersion": "custom.metrics.k8s.io/v1beta1",
    "resources": [
      {
        "name": "jobs.batch/redisqueue_length",
        "singularName": "",
        "namespaced": false,
        "kind": "MetricValueList",
        "verbs": [
          "get"
        ]
      }
    ]
  }
  ```
- Get metric values for one metric

  ```shell
  namespace=suihei
  # metric=kubelet_container_log_filesystem_used_bytes  # test metric
  metric=yourappnamehere_redis_queue_length
  kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/$namespace/pods/*/$metric" | jq .
  ```

# Ports

- `31190`: Prometheus (see [`prometheus-svc.yaml`](/templates/prometheus-svc.yaml))
- `32000`: rq-monitor (see [`rq-monitor.yaml`](/templates/rq-monitor.yaml))
- `36379`: Redis server (see [`redis-server.yaml`](/templates/redis-server.yaml))

# URLs

Use `ip="$(minikube ip)"` to get the IP address of the cluster.

- Get Prometheus metrics:

  ```shell
  curl -XGET "http://$ip:32000/metrics"
  ```

  Sample output:
  ```
  # TYPE yourappnamehere_redis_queue_length gauge
  # HELP yourappnamehere_redis_queue_length Redis queue length
  yourappnamehere_redis_queue_length{queue="high"} 123
  yourappnamehere_redis_queue_length{queue="low"} 45
  # EOF
  ```
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
- Prometheus UI: `http://$ip:31190/graph`

# Troubleshooting

If kubernetes won't allow helm to reinstall the app due to lingering objects after an uninstall, use the following:

```shell
kubectl proxy &  # get a proxy listening on port 8001.
namespace=suihei
curl -k \
	-XPUT \
	-H "Content-Type: application/json" \
	--data-binary '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"'"$namespace"'"},"spec":{"finalizers":[]}}' \
	"http://127.0.0.1:8001/api/v1/namespaces/$namespace/finalize"
```

# License

See [`LICENSE`](/LICENSE) and [`licensing.md`](/licensing.md) for details.
