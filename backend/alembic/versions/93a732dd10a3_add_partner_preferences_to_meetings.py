"""add_partner_preferences_to_meetings

Revision ID: 93a732dd10a3
Revises: 4d88b22b3acb
Create Date: 2026-07-17 06:03:36.958365

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '93a732dd10a3'
down_revision = '4d88b22b3acb'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Пол партнёра (male/female)
    op.add_column("meetings", sa.Column("partner_gender", sa.String(20), nullable=True))
    # Минимальный возраст партнёра
    op.add_column("meetings", sa.Column("partner_min_age", sa.Integer(), nullable=True))
    # Максимальный возраст партнёра
    op.add_column("meetings", sa.Column("partner_max_age", sa.Integer(), nullable=True))
    # Семейное положение (Не важно / Не в браке / В браке)
    op.add_column("meetings", sa.Column("partner_marital_status", sa.String(50), nullable=True))
    # Дети (Не важно / Есть / Нет)
    op.add_column("meetings", sa.Column("partner_has_children", sa.String(10), nullable=True))


def downgrade() -> None:
    op.drop_column("meetings", "partner_has_children")
    op.drop_column("meetings", "partner_marital_status")
    op.drop_column("meetings", "partner_max_age")
    op.drop_column("meetings", "partner_min_age")
    op.drop_column("meetings", "partner_gender")