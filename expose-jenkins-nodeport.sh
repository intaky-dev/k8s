#!/bin/bash

# Script to expose Jenkins via NodePort

echo "Changing Jenkins service to NodePort..."

kubectl patch svc jenkins -n jenkins -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "http",
        "port": 8080,
        "targetPort": 8080,
        "nodePort": 30080
      }
    ]
  }
}'

echo ""
echo "✓ Jenkins is now exposed on NodePort 30080"
echo ""
echo "Access Jenkins at:"
echo "  http://<SERVER-IP>:30080"
echo ""
echo "Get server IP with: hostname -I"
echo ""
