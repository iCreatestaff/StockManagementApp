import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';
import { authenticateToken, requireAdmin, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// GET /api/users - List all users (Admin only)
router.get('/', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const users = await prisma.user.findMany({
            select: {
                id: true,
                username: true,
                role: true,
                isActive: true,
                createdAt: true,
                updatedAt: true,
            },
        });

        res.json(users);
    } catch (error) {
        console.error('Get users error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/users - Create user (Admin only)
router.post('/', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { username, password, role = 'user' } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required' });
        }

        const existingUser = await prisma.user.findUnique({ where: { username } });
        if (existingUser) {
            return res.status(400).json({ error: 'Username already exists' });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const user = await prisma.user.create({
            data: {
                username,
                passwordHash,
                role: role === 'admin' ? 'admin' : 'user',
            },
        });

        res.status(201).json({
            id: user.id,
            username: user.username,
            role: user.role,
            isActive: user.isActive,
        });
    } catch (error) {
        console.error('Create user error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// PUT /api/users/:id - Update user (Admin only)
router.put('/:id', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { username, role, isActive } = req.body;
        const userId = parseInt(id, 10);

        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Check if trying to deactivate or demote the last admin
        if (user.role === 'admin' && (isActive === false || role === 'user')) {
            const adminCount = await prisma.user.count({
                where: { role: 'admin', isActive: true },
            });

            if (adminCount <= 1) {
                return res.status(400).json({ error: 'Cannot deactivate or demote the last admin' });
            }
        }

        // Check username uniqueness if changed
        if (username && username !== user.username) {
            const existingUser = await prisma.user.findUnique({ where: { username } });
            if (existingUser) {
                return res.status(400).json({ error: 'Username already exists' });
            }
        }

        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: {
                username: username ?? user.username,
                role: role ?? user.role,
                isActive: isActive ?? user.isActive,
            },
        });

        res.json({
            id: updatedUser.id,
            username: updatedUser.username,
            role: updatedUser.role,
            isActive: updatedUser.isActive,
        });
    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/users/:id/reset-password - Reset user password (Admin only)
router.post('/:id/reset-password', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { password } = req.body;

        if (!password) {
            return res.status(400).json({ error: 'Password is required' });
        }

        const user = await prisma.user.findUnique({ where: { id: parseInt(id, 10) } });
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        await prisma.user.update({
            where: { id: parseInt(id, 10) },
            data: { passwordHash },
        });

        res.json({ message: 'Password reset successfully' });
    } catch (error) {
        console.error('Reset password error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/users/change-password - User changes own password
router.post('/change-password', authenticateToken, async (req: AuthRequest, res) => {
    try {
        const { currentPassword, newPassword } = req.body;

        if (!currentPassword || !newPassword) {
            return res.status(400).json({ error: 'Current password and new password are required' });
        }

        const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const validPassword = await bcrypt.compare(currentPassword, user.passwordHash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Current password is incorrect' });
        }

        const passwordHash = await bcrypt.hash(newPassword, 10);

        await prisma.user.update({
            where: { id: req.user!.id },
            data: { passwordHash },
        });

        res.json({ message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
