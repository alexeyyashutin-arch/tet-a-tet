import os
import boto3
from botocore.exceptions import ClientError
from fastapi import UploadFile

# Берём настройки из переменных окружения
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "https://storage.yandexcloud.net")
S3_BUCKET = os.getenv("S3_BUCKET", "tet-a-tet-uploads")
S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY", "")
S3_SECRET_KEY = os.getenv("S3_SECRET_KEY", "")

# Инициализируем клиент S3
s3_client = boto3.client(
    's3',
    endpoint_url=S3_ENDPOINT,
    aws_access_key_id=S3_ACCESS_KEY,
    aws_secret_access_key=S3_SECRET_KEY,
    region_name='ru-central1'
)

async def upload_file_to_s3(file: UploadFile, folder: str = "avatars") -> str:
    """Загружает файл в S3 и возвращает публичную ссылку"""
    # Генерируем уникальное имя файла, чтобы они не перезаписывали друг друга
    import uuid
    file_extension = file.filename.split('.')[-1] if file.filename else 'jpg'
    unique_filename = f"{folder}/{uuid.uuid4()}.{file_extension}"
    
    try:
        # Читаем содержимое файла
        file_content = await file.read()
        
        # Определяем Content-Type
        content_type = file.content_type or 'image/jpeg'
        
        # Загружаем в S3
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=unique_filename,
            Body=file_content,
            ContentType=content_type,
            ACL='public-read'  # Делаем файл публичным
        )
        
        # Формируем публичную ссылку
        public_url = f"{S3_ENDPOINT}/{S3_BUCKET}/{unique_filename}"
        print(f"✅ Файл загружен в S3: {public_url}")
        
        return public_url
        
    except ClientError as e:
        print(f"❌ Ошибка загрузки в S3: {e}")
        raise Exception("Не удалось загрузить фото в облако")

async def delete_file_from_s3(file_url: str):
    """Удаляет файл из S3 по его URL"""
    try:
        # Извлекаем ключ файла из URL (например, "avatars/123.jpg")
        # URL выглядит как: https://storage.yandexcloud.net/bucket-name/folder/file.jpg
        key = file_url.split(f"{S3_BUCKET}/")[-1]
        
        s3_client.delete_object(
            Bucket=S3_BUCKET,
            Key=key
        )
        print(f"🗑️ Файл удалён из S3: {key}")
        
    except Exception as e:
        print(f"❌ Ошибка удаления из S3: {e}")