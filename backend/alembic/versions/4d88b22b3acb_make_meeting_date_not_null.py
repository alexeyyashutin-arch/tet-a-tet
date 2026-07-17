"""make_meeting_date_not_null

Revision ID: 4d88b22b3acb
Revises: 87af8eeb2bba
Create Date: 2026-07-17 05:36:39.616319

"""
from alembic import op
import sqlalchemy as sa
from datetime import date, timedelta


# revision identifiers, used by Alembic.
revision = '4d88b22b3acb'
down_revision = '87af8eeb2bba'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Сначала заполняем NULL-значения дефолтной датой (сегодня + 7 дней)
    default_date = date.today() + timedelta(days=7)
    op.execute(
        f"UPDATE meetings SET meeting_date = '{default_date}' WHERE meeting_date IS NULL"
    )
    # Теперь делаем колонку NOT NULL
    op.alter_column("meetings", "meeting_date", existing_type=sa.Date(), nullable=False)


def downgrade() -> None:
    op.alter_column("meetings", "meeting_date", existing_type=sa.Date(), nullable=True)