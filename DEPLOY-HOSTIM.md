# اجرای PasarGuard Node روی Hostim.dev

این مخزن همان Node مستقل PasarGuard را اجرا می‌کند و برای Hostim نیاز به Rathole یا Relay جداگانه ندارد؛ به شرطی که سرویس Hostim پورت `62050` را به‌صورت TCP یا gRPC passthrough در دسترس قرار دهد.

## Deploy

در Hostim یک App از نوع **Git** بساز:

- Repository: `https://github.com/amirmiri138577-droid/node`
- Branch: `main`
- Dockerfile: `Dockerfile`
- معماری: `linux/amd64`
- پورت سرویس: `62050`

در صورت استفاده از Docker Image، تصویر باید `linux/amd64` باشد و پورت پیش‌فرض `62050` را expose کند.

## Volume

یک Volume به App وصل کن و دقیقاً روی این مسیر Mount کن:

```text
/var/lib/pg-node
```

این مسیر شامل Certificate، Private key، API key و فایل `connection-info.txt` است. بدون Volume، پس از restart یا redeploy ممکن است Certificate و API key تغییر کنند.

## Environment variables

```text
NODE_PUBLIC_HOST=<hostname عمومی واقعی که پنل به آن وصل می‌شود>
SERVICE_PORT=62050
SERVICE_PROTOCOL=grpc
NODE_HOST=0.0.0.0
API_KEY=<یک UUID معتبر>
AUTO_GENERATE_CERT=true
REGENERATE_CERT_ON_HOST_CHANGE=true
PRINT_CONNECTION_INFO=true
```

`NODE_PUBLIC_HOST` فقط hostname است و نباید scheme یا port داشته باشد:

```text
NODE_PUBLIC_HOST=node.example.com
```

فرمت‌های نادرست:

```text
NODE_PUBLIC_HOST=https://node.example.com
NODE_PUBLIC_HOST=node.example.com:62050
```

## اتصال به پنل

بعد از اولین اجرا، Log را باز کن و این مقادیر را بردار:

```text
Address: مقدار NODE_PUBLIC_HOST
Port: پورت عمومی‌ای که Hostim برای سرویس اعلام می‌کند
Protocol: grpc
API Key: مقدار API_KEY
Certificate: کل متن PEM
```

Certificate را کامل، از `BEGIN CERTIFICATE` تا `END CERTIFICATE`، داخل پنل PasarGuard قرار بده.

## شرط حیاتی Hostim

Hostim برای Appها دامنهٔ HTTPS و SSL مدیریت‌شده ارائه می‌کند، اما در مستندات عمومی بررسی‌شده صراحتاً تضمین نشده که پورت عمومی App برای **raw TCP** یا **gRPC/TLS passthrough** باز باشد.

PasarGuard Node خودش TLS/gRPC را روی `62050` terminate می‌کند. بنابراین یکی از این دو حالت باید برقرار باشد:

1. Hostim پورت TCP عمومی را مستقیماً به `62050` وصل کند؛ یا
2. Hostim برای دامنه، gRPC over HTTP/2 را بدون terminate کردن TLS به Node عبور دهد.

اگر Hostim فقط HTTP/HTTPS معمولی را reverse-proxy کند و TLS را خودش terminate کند، این Node با دامنهٔ Hostim کار نخواهد کرد؛ چون پنل PasarGuard به gRPC/TLS و Certificate خود Node نیاز دارد. در آن حالت باید از VPS یا سرویس دارای TCP Proxy استفاده شود.

قبل از انتقال کامل، این موارد را با یک استقرار آزمایشی تست کن:

- Log شامل `PasarGuard Node is ready` باشد.
- پورت عمومی واقعاً TCP اتصال را قبول کند.
- پنل بتواند با API key و Certificate به Node وصل شود.
- بعد از restart، Address و Certificate ثابت بمانند.
- قابلیت‌های WireGuard/Xray را جداگانه تست کن؛ بالا آمدن API به‌تنهایی data-plane را تضمین نمی‌کند.

## سیاست استفاده

پیش از Deploy، قوانین فعلی Hostim را بررسی کن. Terms عمومی Hostim در زمان بررسی VPN/Proxy را مثل Runsite صراحتاً نام نبرده، اما network scanning، سوءاستفاده، مصرف بیش‌ازحد منابع و فعالیتی که به زیرساخت یا اعتبار آن‌ها آسیب بزند ممنوع است. اگر پشتیبانی Hostim دربارهٔ PasarGuard Node یا عبور ترافیک سؤال کرد، نوع واقعی workload را شفاف توضیح بده و منتظر تأیید بمان.
