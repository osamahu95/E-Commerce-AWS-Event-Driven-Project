.PHONY: up down reset ps logs ping

up:        ## start core infra (localstack + redis) in background
	docker compose up -d

down:      ## stop containers, KEEP data volumes
	docker compose down

reset:     ## stop AND wipe volumes (fresh slate)
	docker compose down -v

ps:        ## show running services
	docker compose ps

logs:      ## follow logs
	docker compose logs -f

ping:      ## smoke test the running infra
	docker exec edop-redis redis-cli ping
	awslocal sqs list-queues
	awslocal dynamodb list-tables