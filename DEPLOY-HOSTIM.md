# اجرای PasarGuard Node روی Hostim با دامنهٔ خود پروژه

## نتیجهٔ تحقیق دربارهٔ Hostim

Hostim برای Appها یک **HTTP Service** با `httpPort` و دامنهٔ HTTPS ارائه می‌کند. در API عمومی Hostim فیلدی برای TCP Proxy یا public raw port وجود ندارد؛ بنابراین تنظیم پورت `62050` به‌عنوان پورت عمومی قبلی درست نبود.

این نسخه از معماری زیر استفاده می‌کند:

```text
PasarGuard panel
      │ HTTPS / HTTP2 gRPC
      ▼
Hostim domain:443
      │ Hostim HTTP ingress
      ▼
Nginx gRPC bridge:8080
      │ local gRPC over TLS
      ▼
PasarGuard Node:62050
```

در این حالت Address نود، **دامنهٔ خود Hostim App** است و Relay جداگانه لازم نیست.

> این روش فقط در صورتی کار می‌کند که HTTP ingress Hostim، درخواست gRPC/HTTP2 را به App منتقل کند. مستندات Hostim پشتیبانی gRPC را صراحتاً تضمین نکرده‌اند؛ اگر ingress درخواست را به HTTP/1.1 تبدیل کند، اجرای Node از طریق دامنهٔ Hostim ممکن نیست و باید از VPS یا TCP Proxy استفاده شود.

## Deploy از Git

در Hostim یک App از نوع **Git** بساز:

- Repository: `https://github.com/amirmiri138577-droid/node`
- Branch: `main`
- Dockerfile: `Dockerfile`
- Architecture: `linux/amd64`
- HTTP port: `8080`
- Public app: فعال
- Health check: خالی/غیرفعال در تست اول
- Replicas: `1`

پورت Hostim در این نسخه **8080** است. پورت `62050` فقط داخل کانتینر و بین Nginx و Node استفاده می‌شود.

## Volume

یک Volume بساز و روی App با این مسیر Mount کن:

```text
/var/lib/pg-node
```

این Volume برای ثابت‌ماندن API Key و Certificate لازم است.

## Environment variables

برای استفاده از دامنهٔ خودکار Hostim، این مقدار را تنظیم کن:

```text
NODE_PUBLIC_HOST=$(BUILTIN_DOMAIN)
SERVICE_PORT=62050
SERVICE_PROTOCOL=grpc
NODE_HOST=0.0.0.0
PORT=8080
HOSTIM_HTTP_BRIDGE=true
API_KEY=<یک UUID معتبر>
AUTO_GENERATE_CERT=true
REGENERATE_CERT_ON_HOST_CHANGE=true
PRINT_CONNECTION_INFO=true
```

در صورت استفاده از دامنهٔ شخصی، مقدار `NODE_PUBLIC_HOST` باید همان hostname دامنهٔ متصل‌شده باشد:

```text
NODE_PUBLIC_HOST=node.example.com
```

در هر دو حالت، scheme و port داخل مقدار نگذار:

```text
NODE_PUBLIC_HOST=https://node.example.com  # نادرست
NODE_PUBLIC_HOST=node.example.com:443      # نادرست
```

Hostim مقدار `$(BUILTIN_DOMAIN)` را به hostname واقعی App تبدیل می‌کند. اگر این جایگزینی در نسخهٔ فعلی Console انجام نشد، دامنهٔ واقعی Hostim را از صفحهٔ Domains کپی کن و مستقیم در `NODE_PUBLIC_HOST` قرار بده.

## اطلاعات داخل پنل PasarGuard

آدرس پنل باید همان دامنهٔ Hostim باشد:

```text
Address: <دامنهٔ Hostim App>
Port: 443
Protocol: grpc
API Key: مقدار API_KEY
Certificate: گواهی TLS عمومی دامنهٔ Hostim، در صورت اجباری‌بودن فیلد
```

پورت `62050` را در پنل وارد نکن؛ این پورت عمومی نیست.

برای مشاهدهٔ گواهی عمومی دامنه:

```bash
openssl s_client -connect <hostim-domain>:443 \
  -servername <hostim-domain> -showcerts </dev/null 2>/dev/null
```

گواهی بین `BEGIN CERTIFICATE` و `END CERTIFICATE` را بردار. اگر پنل با گواهی عمومی سیستم بدون واردکردن Certificate کار می‌کند، فیلد Certificate را خالی بگذار.

## تست مرحله‌ای

1. در Log باید این پیام‌ها را ببینی:

   ```text
   PasarGuard Node is ready
   starting Hostim HTTP/2 gRPC bridge on 8080
   ```

2. دامنهٔ Hostim را با مرورگر باز کن. نمایش خطای متنی از gRPC طبیعی است؛ مهم این است که پاسخ `502` یا `connection refused` نباشد.
3. در پنل PasarGuard، Address را hostname دامنه و Port را `443` بگذار.
4. ابتدا فقط اتصال Node/API را تست کن.
5. سپس Xray/WireGuard و data-plane را جداگانه تست کن.

## خطاهای متداول

### `502 Bad Gateway`

Nginx یا Node بالا نیامده است. Log کانتینر و Volume را بررسی کن.

### `400`, `404` یا پاسخ HTTP ساده

ممکن است Hostim ingress درخواست gRPC را به HTTP/1.1 تبدیل کند. PasarGuard Node به HTTP/2 gRPC نیاز دارد.

### پنل به Certificate اعتماد نمی‌کند

گواهی عمومی همان دامنهٔ Hostim را از طریق `openssl s_client` بگیر. اگر پنل فقط Certificate تولیدشده توسط خود Node را قبول کند، این bridge مناسب نیست؛ چون TLS بیرونی در Hostim terminate می‌شود.

### API آنلاین است ولی WireGuard/Xray کار نمی‌کند

این دو موضوع جدا هستند. Hostim App ممکن است API را اجرا کند اما قابلیت‌های نیازمند kernel capability یا چند پورت ورودی را ارائه ندهد.

## سیاست استفاده

این نسخه هیچ سیستم تشخیص Hostim را دور نمی‌زند و فقط از HTTP Service مستندشده استفاده می‌کند. بااین‌حال، قبل از استفادهٔ واقعی قوانین Hostim را بررسی کن. Terms عمومی Hostim network scanning، سوءاستفاده، مصرف غیرعادی منابع و فعالیت تهدیدکنندهٔ زیرساخت را ممنوع می‌کند. اگر دربارهٔ PasarGuard Node یا عبور ترافیک سؤال شد، نوع واقعی workload را شفاف به پشتیبانی اعلام کن.
