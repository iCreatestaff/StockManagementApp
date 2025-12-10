import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken, requireAdmin, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// GET /api/stats - Get dashboard statistics (Admin only)
router.get('/', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        // 1. Inventory Stats
        const [totalProducts, totalQuantityResult, lowStockCount] = await Promise.all([
            prisma.product.count({ where: { isActive: true } }),
            prisma.product.aggregate({
                _sum: { quantity: true },
                where: { isActive: true }
            }),
            prisma.product.count({
                where: {
                    isActive: true,
                    quantity: { lte: prisma.product.fields.minQuantity }
                }
            })
        ]);

        const totalQuantity = totalQuantityResult._sum.quantity || 0;

        // 2. Activity Stats (Last 30 days)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const movements = await prisma.movement.findMany({
            where: {
                timestamp: { gte: thirtyDaysAgo },
                isUndone: false
            },
            select: {
                operationType: true,
                quantityChange: true
            }
        });

        const movementsByType = movements.reduce((acc, curr) => {
            acc[curr.operationType] = (acc[curr.operationType] || 0) + 1;
            return acc;
        }, {} as Record<string, number>);

        // 3. Top Movers (Products with most movements in last 30 days)
        const topMovers = await prisma.movement.groupBy({
            by: ['productId', 'productName'],
            where: {
                timestamp: { gte: thirtyDaysAgo },
                isUndone: false
            },
            _count: {
                id: true
            },
            orderBy: {
                _count: {
                    id: 'desc'
                }
            },
            take: 5
        });

        res.json({
            inventory: {
                totalProducts,
                totalQuantity,
                lowStockCount
            },
            activity: {
                totalMovements: movements.length,
                byType: movementsByType
            },
            topMovers: topMovers.map(m => ({
                productId: m.productId,
                productName: m.productName,
                count: m._count.id
            }))
        });

    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
