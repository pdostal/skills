# Command variants

## openqa-clone-job

Clones a job from one openQA instance to another.

```sh
openqa-clone-job --host <target-host> --from <source-host> $JOB_ID [--skip-deps] [VAR=value …]
```

- `--from <source-host>` — derive automatically from the overview URL hostname;
  do not require the user to specify it unless their template already contains it.
- `--host <target-host>` — always provided by the user in their template.
- `--skip-deps` and any extra `VAR=value` overrides — pass through verbatim
  from the user's template, appended after the job ID.

Example output:

```sh
# EC2-BYOS-Updates / x86_64 / failed
openqa-clone-job --host myhost.example.org --from openqa.suse.de 22839669 --skip-deps PUBLIC_CLOUD_DMS_REPO=
```

## openqa-cli

Performs API actions (e.g. restart) directly on the source openQA instance.

```sh
openqa-cli api --host https://<source-host> -X POST jobs/$JOB_ID/restart
```

- The source host is derived automatically from the overview URL hostname.
- If the user's template uses `openqa-cli`, substitute `$JOB_ID` into the
  appropriate position in their template exactly as with `openqa-clone-job`.

Example output:

```sh
# Azure-BYOS-Updates / aarch64 / failed
openqa-cli api --host https://openqa.suse.de -X POST jobs/22839982/restart
```
