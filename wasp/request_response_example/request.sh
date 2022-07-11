curl --location --request GET 'https://ads-acceptance.internal-weedmaps.com/ads' \
--header 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206 Safari/7534.48.3' \
--header 'X-Forwarded-For: 10.0.0.21' \
--header 'X-Wasp-Explain: 1' \
--header 'Content-Type: application/json' \
--data-raw '{
    "placements": [{
            "divName": "carousel-1",
            "networkId": 10315,
            "siteId": 1097238,
            "adTypes": [
                163
            ],
            "zoneIds": [
                211135
            ],
            "properties": {
                "homepageCarouselStatic": true
            },
            "count": 1
        },
        {
            "divName": "carousel-2",
            "networkId": 10315,
            "siteId": 1097238,
            "adTypes": [
                163
            ],
            "zoneIds": [
                211136
            ],
            "properties": {
                "homepageCarouselStatic": true
            },
            "count": 1
        },
        {
            "divName": "carousel-3",
            "networkId": 10315,
            "siteId": 1097238,
            "adTypes": [
                163
            ],
            "zoneIds": [
                211137
            ],
            "properties": {
                "homepageCarouselStatic": true
            },
            "count": 1
        },
        {
            "divName": "carousel-4",
            "networkId": 10315,
            "siteId": 1097238,
            "adTypes": [
                163
            ],
            "zoneIds": [
                211138
            ],
            "properties": {
                "homepageCarouselStatic": true
            },
            "count": 1
        }
    ],
    "keywords": [
        "country:us",
        "state:mi",
        "city:flint",
        "zipcode:48504",
        "sales-region:676",
        "online-ordering",
        "medical-legal"
    ]
}'
