curl --location --request GET 'https://ads-production.internal-weedmaps.com/ads' \
--header 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206 Safari/7534.48.3' \
--header 'X-Forwarded-For: 10.0.0.21' \
--header 'Content-Type: application/json' \
--data-raw '{
    "placements": [{
        "divName": "homepage-carousel-1",
        "zoneIds": [
            211872
        ],
        "count": 1
    }],
    "keywords": [
        "sales-region:708"
    ]
}'
