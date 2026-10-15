# Докер образ self-hosted GitHub Actions runner

Runner на базе официального образа `ghcr.io/actions/actions-runner` с клиентом MinIO `mc`.
Нужен, чтобы выкладывать собранную статику в MinIO: сборка идёт на машинах GitHub, а этот runner
только скачивает артефакт и делает `mc mirror` (см. `deploy_for_static_site` в
[all-workflows](https://github.com/moogur/all-workflows)).

Docker внутри runner'а нет: ни `docker.sock`, ни `--privileged`. Контейнер непривилегированный и
работает с userns-remap. Портов наружу не открывает — сам ходит в GitHub по HTTPS.

## Версии

Задаются в [`Dockerfile`](Dockerfile) через `ARG`:

| `ARG` | Что задаёт |
| --- | --- |
| `RUNNER_VERSION` | Тег образа `ghcr.io/actions/actions-runner` ([релизы](https://github.com/actions/runner/releases)) |
| `MC_VERSION` | Релиз `mc` на GitHub |
| `MC_SHA256` | Контрольная сумма `mc.linux-amd64.<MC_VERSION>` из файла `.sha256sum` релиза |

`mc` берётся из [релизов на GitHub](https://github.com/minio/mc/releases): проект MinIO заархивирован,
и dl.min.io бинарники больше не раздаёт. Обновлений `mc` больше не будет.

Runner обновляет себя сам, пока контейнер жив; после перезапуска он снова стартует с версии из образа
и обновляется заново. Поднимать `RUNNER_VERSION` всё равно стоит, чтобы не качать обновление на
каждом старте.

## Запуск

Переменные окружения контейнера:

| Переменная | Что задаёт |
| --- | --- |
| `RUNNER_URL` | Репозиторий, к которому привязан runner. **Только приватный**: в публичном PR из форка смог бы исполнить код на сервере |
| `RUNNER_TOKEN` | Одноразовый токен из Settings → Actions → Runners → New self-hosted runner. Нужен только при первом старте |
| `RUNNER_NAME` | Имя runner'а (необяз., по умолчанию hostname контейнера) |
| `MC_HOST_minio` | Алиас `minio` для `mc`: `https://<access key>:<secret key>@<адрес MinIO>`, спецсимволы ключей кодируются как в URL |

Регистрацию [`entrypoint.sh`](entrypoint.sh) при первом старте сохраняет в `/home/runner/state` —
туда нужно смонтировать volume, иначе после пересоздания контейнера runner придётся регистрировать
заново. В volume лежат учётные данные runner'а: кто его унёс, тот и runner.

Перерегистрировать (другой репозиторий, новое имя): удалить runner в настройках репозитория,
очистить volume и запустить контейнер со свежим `RUNNER_TOKEN`.

## Пользователь MinIO

Ключи — отдельного пользователя с политикой только на нужный бакет (в примере `<bucket>`).
`DeleteObject` нужен для `mc mirror --remove`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["s3:ListBucket"], "Resource": ["arn:aws:s3:::<bucket>"] },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::<bucket>/*"]
    }
  ]
}
```

## Образ

Публикуется в GitHub Packages:

```text
docker.pkg.github.com/moogur/docker-for-gh-runner/docker-for-gh-runner:<тег>
```

| Тег | Что означает |
| --- | --- |
| `v1.1.1` | Конкретный релиз, никогда не меняется |
| `v1.1` | Последний патч минорной версии |
| `v1` | Последний релиз мажорной версии |
| `latest` | Последний релиз вообще |

## Релиз

Сборка и публикация образа идут по пушу git-тега формата `vX.Y.Z`
([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)):

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow вызывает `deploy_for_docker_container` из all-workflows, он раскладывает тег в
`v1.0.0`, `v1.0`, `v1`, `latest`. Задачи Kaneo из коммитов между двумя последними тегами уходят в
`done` с версией. Пуш в `master` образ не собирает, только переводит задачу в `in-progress`
([`.github/workflows/push.yml`](.github/workflows/push.yml)). Нужны секреты `KANEO_HOST`, `KANEO_TOKEN`.

## Разработка

```bash
npm install                                     # husky и git-хуки
docker build -t docker-for-gh-runner:local .    # локальная сборка
```

Сообщения коммитов проверяет хук [`.husky/commit-msg`](.husky/commit-msg), валидируется только заголовок:

```text
[DOC-<номер>] <type>(<scope>): <subject>
```

Допустимые `type`: `feature`, `bugfix`, `ci`, `config`, `refactor`, `test`, `docs`; `scope` и
`subject` — нижний регистр, `subject` не длиннее 125 символов.
