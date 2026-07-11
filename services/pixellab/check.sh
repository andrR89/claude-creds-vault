#!/usr/bin/env bash
# PixelLab API: bearer com o token da conta. GET /balance é autenticado e barato.
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $PIXELLAB_API_KEY" "https://api.pixellab.ai/v2/balance")
echo "pixellab: $code"
