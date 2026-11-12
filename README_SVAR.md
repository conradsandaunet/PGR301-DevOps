# PGR301-DevOps

Kandidatnummer: 26

## Oppgave 1 - Container og CI

### 1A - Dockerfile

Det ligger en multi-stage Dockerfile i prosjektmappen.
Starte containteren på `localhost:9999`:

```bash
docker build -t wishifai .
docker run -p 9999:8080 \
  -e AWS_ACESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -e AWS_REGION=eu-west-1 \
  -e S3_BUCKET=<bucketname> \
  whishifai
```

### 1B - CI-pipeline

Workflow: `.github/workflows/docker.yml`. Den kjører kun ved push til `main`, logger inn mot AWS med Github Secrets, bygger imaget og pusher til ECR.

Lenke til grønn kjøring: https://github.com/conradsandaunet/PGR301-DevOps/actions/runs/42629366743.

**Tagging-stragegi:** Imaget tagges med full commit-SHA.
Begrunnelse:
- Hver tag peker på nøyaktig en commit, så det er mulig å spore hva som kjører hvor.
- ECR-repoet har immutable tags, så en SHA-tag kan aldri overskrives ved et uhell.
- Rollback gjøres ved å deploye en tidligere SHA.


## Oppgave 2 - ECS Express og Terraform

### 2A - Infrastruktur

All Terraform ligger i `infra/`.
Offentlig URL: https://wi-e582d58f423745aaafcb903a25f14ffa.ecs.eu-west-1.on.aws

Valg og begrunnelser:
- **Eksisterende roller:** Execution role og infrastructure role er hentet fra klassens konto, som oppgaven ba om.
- **Task role:** Credentials kommer fra rollen, så ingen nøkler ligger i containeren.
- **Variabler:** `region`, `candidate`, `image_tag` og `bedrock_model_id`. 
- **Output:** `service_url`, `bucket_name`, `task_role_arn`.

Kjøre koden:

```bash
cd infra
terraform init
terraform apply -var="candidate=26" -var="image_tag=<commit-SHA>"
```

### 2B - Remote state

State ligger i S3-bøtta `pgr301-terraform-state` med nøkkel:

```
whishifai/26/terrafor.tfstate
```

Begrunnelse:
- Bøtta deles av klassen, så kandidatnummer i nøkkelen gjør at state-filen er unik.
- Kandidatnummer er hardkodet fordi `backend`-blokken ikke støtter variabler.

### 2C - Github Actions-job

Workflow: `.github/workflows/docker.yml` har to jobs:
1. `build and push` bygger og pusher imaget til ECR
2. `terraform` har `needs: build and push`, og kjører `fmt -check`, `init`, `validate` og `apply` mot `/infra`.
Lenke til grønn kjøring: https://github.com/conradsandaunet/PGR301-DevOps/actions/runs/43033394191.

Det er fornuftig at Terraform kjører etter container-build fordi Terraform refererer til en bestemt image-tag. Hvis Terraform
kjørte før eller parallelt, kunne tjenesten peke på et image som ikke finnes enda, og deploy ville feilet.
Etter build er imaget garantert i ECR, så det som deployes er det som ble bygget fra akkurat den commiten.
Hvis build feiler, stoppes pipelinen før noe infrastruktur endres.
