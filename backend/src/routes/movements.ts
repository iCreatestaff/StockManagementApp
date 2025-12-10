import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken, requireAdmin, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// GET /api/movements - List movements with filtering, sorting, pagination (Admin only)
router.get('/', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const {
            productId,
            userId,
            operationType,
            startDate,
            endDate,
            search,
            sortBy = 'timestamp',
            sortOrder = 'desc',
            page = '1',
            limit = '20',
        } = req.query;

        const pageNum = parseInt(page as string, 10);
        const limitNum = parseInt(limit as string, 10);
        const skip = (pageNum - 1) * limitNum;

        const where: any = {};

        if (productId) {
            where.productId = parseInt(productId as string, 10);
        }

        if (userId) {
            where.userId = parseInt(userId as string, 10);
        }

        if (operationType) {
            where.operationType = operationType as string;
        }

        if (startDate || endDate) {
            where.timestamp = {};
            if (startDate) {
                where.timestamp.gte = new Date(startDate as string);
            }
            if (endDate) {
                where.timestamp.lte = new Date(endDate as string);
            }
        }

        if (search) {
            where.OR = [
                { details: { contains: search as string } },
                { productName: { contains: search as string } },
                { username: { contains: search as string } },
            ];
        }

        const orderBy: any = {};
        orderBy[sortBy as string] = sortOrder === 'asc' ? 'asc' : 'desc';

        const [movements, total] = await Promise.all([
            prisma.movement.findMany({
                where,
                orderBy,
                skip,
                take: limitNum,
                include: {
                    originalMovement: {
                        select: {
                            id: true,
                            operationType: true,
                            quantityChange: true,
                        },
                    },
                },
            }),
            prisma.movement.count({ where }),
        ]);

        res.json({
            data: movements,
            pagination: {
                page: pageNum,
                limit: limitNum,
                total,
                totalPages: Math.ceil(total / limitNum),
            },
        });
    } catch (error) {
        console.error('Get movements error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/movements/:id/undo - Undo a movement (Admin only)
router.post('/:id/undo', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const movementId = parseInt(id, 10);

        const movement = await prisma.movement.findUnique({
            where: { id: movementId },
        });

        if (!movement) {
            return res.status(404).json({ error: 'Movement not found' });
        }

        // Check if already undone
        if (movement.isUndone) {
            return res.status(400).json({ error: 'This movement has already been undone' });
        }

        // Only allow undo for add, take, adjust
        if (!['add', 'take', 'adjust'].includes(movement.operationType)) {
            return res.status(400).json({ error: 'Cannot undo this type of operation' });
        }

        // Get current product state
        const product = await prisma.product.findUnique({
            where: { id: movement.productId },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product no longer exists' });
        }

        // Calculate the reversal
        const reversalChange = -movement.quantityChange;
        const newQuantity = product.quantity + reversalChange;

        // Validate the reversal won't cause negative stock
        if (newQuantity < 0) {
            return res.status(400).json({
                error: `Cannot undo: would result in negative stock (current: ${product.quantity}, change: ${reversalChange})`,
            });
        }

        // Perform the undo in a transaction
        const [updatedProduct, undoMovement] = await prisma.$transaction([
            // Update product quantity
            prisma.product.update({
                where: { id: product.id },
                data: { quantity: newQuantity },
            }),
            // Create undo movement
            prisma.movement.create({
                data: {
                    productId: product.id,
                    productName: product.name,
                    userId: req.user!.id,
                    username: req.user!.username,
                    operationType: 'undo',
                    quantityChange: reversalChange,
                    oldQuantity: product.quantity,
                    newQuantity,
                    details: `Undo of ${movement.operationType} operation (ID: ${movement.id})`,
                    originalMovementId: movement.id,
                },
            }),
            // Mark original as undone
            prisma.movement.update({
                where: { id: movement.id },
                data: { isUndone: true },
            }),
        ]);

        res.json({
            message: 'Operation undone successfully',
            undoMovement,
            product: {
                ...updatedProduct,
                isLowStock: updatedProduct.quantity <= updatedProduct.minQuantity,
            },
        });
    } catch (error) {
        console.error('Undo movement error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
