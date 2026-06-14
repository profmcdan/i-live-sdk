"""add face verification and channel

Revision ID: 003
Revises: 002
Create Date: 2026-06-14 23:14:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '003'
down_revision: Union[str, None] = '002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. Add columns to customers
    op.add_column('customers', sa.Column('channel', sa.String(), nullable=False, server_default='personal'))
    op.add_column('customers', sa.Column('reference_image_path', sa.String(), nullable=True))
    
    # Create unique constraint on (bvn, channel) for customers
    op.create_unique_constraint('_bvn_channel_uc', 'customers', ['bvn', 'channel'])

    # 2. Add columns to liveness_sessions
    op.add_column('liveness_sessions', sa.Column('channel', sa.String(), nullable=True, server_default='personal'))
    op.add_column('liveness_sessions', sa.Column('verification_type', sa.String(), nullable=False, server_default='ONBOARDING'))
    op.add_column('liveness_sessions', sa.Column('face_match_status', sa.String(), nullable=True))
    op.add_column('liveness_sessions', sa.Column('face_match_confidence', sa.Float(), nullable=True))

def downgrade() -> None:
    # Remove columns from liveness_sessions
    op.drop_column('liveness_sessions', 'face_match_confidence')
    op.drop_column('liveness_sessions', 'face_match_status')
    op.drop_column('liveness_sessions', 'verification_type')
    op.drop_column('liveness_sessions', 'channel')

    # Remove unique constraint and columns from customers
    op.drop_constraint('_bvn_channel_uc', 'customers', type_='unique')
    op.drop_column('customers', 'reference_image_path')
    op.drop_column('customers', 'channel')
