"""make_meeting_date_nullable_remove_time

Revision ID: 87af8eeb2bba
Revises: 75aa4a8f7a4e
Create Date: 2026-07-16 14:23:03.773739

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '87af8eeb2bba'
down_revision = '75aa4a8f7a4e'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Делаем meeting_date необязательным
    op.alter_column("meetings", "meeting_date", existing_type=sa.Date(), nullable=True)
    # Удаляем meeting_time (больше не нужно)
    op.drop_column("meetings", "meeting_time")


def downgrade() -> None:
    # Возвращаем meeting_date как обязательный
    op.alter_column("meetings", "meeting_date", existing_type=sa.Date(), nullable=False)
    # Возвращаем meeting_time
    op.add_column("meetings", sa.Column("meeting_time", sa.String(10), nullable=True))