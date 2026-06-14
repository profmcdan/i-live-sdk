"""initial schema

Revision ID: 001
Revises: 
Create Date: 2026-06-14 22:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. Create users table
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('hashed_password', sa.String(), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('created_at', sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)

    # 2. Create invites table
    op.create_table(
        'invites',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('created_by', sa.String(), nullable=False),
        sa.Column('is_used', sa.Boolean(), nullable=False),
        sa.Column('used_by', sa.String(), nullable=True),
        sa.Column('created_at', sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_invites_code'), 'invites', ['code'], unique=True)
    op.create_index(op.f('ix_invites_id'), 'invites', ['id'], unique=False)

    # 3. Create liveness_sessions table
    op.create_table(
        'liveness_sessions',
        sa.Column('session_id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=True),
        sa.Column('provider', sa.String(), nullable=False),
        sa.Column('liveness_mode', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('confidence', sa.Float(), nullable=False),
        sa.Column('image_reference', sa.String(), nullable=True),
        sa.Column('video_reference', sa.String(), nullable=True),
        sa.Column('device_intelligence', sa.Text(), nullable=True),
        sa.Column('created_at', sa.Float(), nullable=False),
        sa.Column('updated_at', sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint('session_id')
    )
    op.create_index(op.f('ix_liveness_sessions_session_id'), 'liveness_sessions', ['session_id'], unique=False)
    op.create_index(op.f('ix_liveness_sessions_user_id'), 'liveness_sessions', ['user_id'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_liveness_sessions_user_id'), table_name='liveness_sessions')
    op.drop_index(op.f('ix_liveness_sessions_session_id'), table_name='liveness_sessions')
    op.drop_table('liveness_sessions')
    op.drop_index(op.f('ix_invites_id'), table_name='invites')
    op.drop_index(op.f('ix_invites_code'), table_name='invites')
    op.drop_table('invites')
    op.drop_index(op.f('ix_users_id'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
