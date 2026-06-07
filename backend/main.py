from fastapi import FastAPI

# Создаём экземпляр нашего приложения. 
# title и description будут красиво отображаться в авто-документации Swagger!
app = FastAPI(
    title="Tête-à-tête API",
    description="Премиальный приватный сервис для романтических встреч",
    version="1.0.0"
)

# Самый первый и простой маршрут (endpoint). 
# Когда кто-то обратится к корню нашего сервера, мы ответим ему изящным сообщением.
@app.get("/")
async def root():
    return {"message": "Добро пожаловать в Tête-à-tête. Здесь начинается магия. ✨"}

# Маршрут для проверки того, что всё работает (health check)
@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "backend is running smoothly"}