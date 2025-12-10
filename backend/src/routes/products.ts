import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken, requireAdmin, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// GET /api/products - List products with filtering, sorting, pagination
router.get('/', authenticateToken, async (req: AuthRequest, res) => {
    try {
        const {
            search,
            category,
            isActive,
            lowStock,
            sortBy = 'name',
            sortOrder = 'asc',
            page = '1',
            limit = '20',
        } = req.query;

        const pageNum = parseInt(page as string, 10);
        const limitNum = parseInt(limit as string, 10);
        const skip = (pageNum - 1) * limitNum;

        const where: any = {};

        // Search by name or SKU
        if (search) {
            where.OR = [
                { name: { contains: search as string } },
                { sku: { contains: search as string } },
            ];
        }

        // Filter by category
        if (category) {
            where.category = category as string;
        }

        // Filter by active status
        if (isActive !== undefined) {
            where.isActive = isActive === 'true';
        }

        // Filter by low stock
        if (lowStock === 'true') {
            where.quantity = { lte: prisma.product.fields.minQuantity };
        }

        const orderBy: any = {};
        orderBy[sortBy as string] = sortOrder === 'desc' ? 'desc' : 'asc';

        const [products, total] = await Promise.all([
            prisma.product.findMany({
                where,
                orderBy,
                skip,
                take: limitNum,
            }),
            prisma.product.count({ where }),
        ]);

        // Add low stock indicator
        const productsWithIndicator = products.map((p) => ({
            ...p,
            isLowStock: p.quantity <= p.minQuantity,
        }));

        res.json({
            data: productsWithIndicator,
            pagination: {
                page: pageNum,
                limit: limitNum,
                total,
                totalPages: Math.ceil(total / limitNum),
            },
        });
    } catch (error) {
        console.error('Get products error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// GET /api/products/:id - Get product details
router.get('/:id', authenticateToken, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const product = await prisma.product.findUnique({
            where: { id: parseInt(id, 10) },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        res.json({
            ...product,
            isLowStock: product.quantity <= product.minQuantity,
        });
    } catch (error) {
        console.error('Get product error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/products - Create product (Admin only)
router.post('/', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { name, sku, quantity = 0, unit = 'pcs', minQuantity = 0, category, location, notes } = req.body;

        if (!name || !sku) {
            return res.status(400).json({ error: 'Name and SKU are required' });
        }

        const existingProduct = await prisma.product.findUnique({ where: { sku } });
        if (existingProduct) {
            return res.status(400).json({ error: 'SKU already exists' });
        }

        const product = await prisma.product.create({
            data: {
                name,
                sku,
                quantity,
                unit,
                minQuantity,
                category,
                location,
                notes,
            },
        });

        // Create movement record for initial stock
        if (quantity > 0) {
            await prisma.movement.create({
                data: {
                    productId: product.id,
                    productName: product.name,
                    userId: req.user!.id,
                    username: req.user!.username,
                    operationType: 'add',
                    quantityChange: quantity,
                    oldQuantity: 0,
                    newQuantity: quantity,
                    details: 'Initial stock on product creation',
                },
            });
        }

        res.status(201).json(product);
    } catch (error) {
        console.error('Create product error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// PUT /api/products/:id - Update product (Admin only)
router.put('/:id', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { name, sku, unit, minQuantity, category, location, notes } = req.body;

        const product = await prisma.product.findUnique({
            where: { id: parseInt(id, 10) },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        // Check SKU uniqueness if changed
        if (sku && sku !== product.sku) {
            const existingProduct = await prisma.product.findUnique({ where: { sku } });
            if (existingProduct) {
                return res.status(400).json({ error: 'SKU already exists' });
            }
        }

        const updatedProduct = await prisma.product.update({
            where: { id: parseInt(id, 10) },
            data: {
                name: name ?? product.name,
                sku: sku ?? product.sku,
                unit: unit ?? product.unit,
                minQuantity: minQuantity ?? product.minQuantity,
                category: category ?? product.category,
                location: location ?? product.location,
                notes: notes ?? product.notes,
            },
        });

        // Create edit movement record
        await prisma.movement.create({
            data: {
                productId: product.id,
                productName: updatedProduct.name,
                userId: req.user!.id,
                username: req.user!.username,
                operationType: 'edit',
                quantityChange: 0,
                oldQuantity: product.quantity,
                newQuantity: product.quantity,
                details: `Product details updated`,
            },
        });

        res.json(updatedProduct);
    } catch (error) {
        console.error('Update product error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/products/:id/take - Take from stock (Any authenticated user)
router.post('/:id/take', authenticateToken, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { quantity, details } = req.body;

        if (!quantity || quantity <= 0) {
            return res.status(400).json({ error: 'Quantity must be a positive number' });
        }

        const product = await prisma.product.findUnique({
            where: { id: parseInt(id, 10) },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        if (!product.isActive) {
            return res.status(400).json({ error: 'Cannot take from inactive product' });
        }

        if (quantity > product.quantity) {
            return res.status(400).json({ error: 'Cannot take more than available stock' });
        }

        const newQuantity = product.quantity - quantity;

        const updatedProduct = await prisma.product.update({
            where: { id: parseInt(id, 10) },
            data: { quantity: newQuantity },
        });

        await prisma.movement.create({
            data: {
                productId: product.id,
                productName: product.name,
                userId: req.user!.id,
                username: req.user!.username,
                operationType: 'take',
                quantityChange: -quantity,
                oldQuantity: product.quantity,
                newQuantity,
                details: details || null,
            },
        });

        res.json({
            ...updatedProduct,
            isLowStock: updatedProduct.quantity <= updatedProduct.minQuantity,
        });
    } catch (error) {
        console.error('Take from stock error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/products/:id/adjust - Adjust stock (Admin only)
router.post('/:id/adjust', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { quantity, details } = req.body;

        if (quantity === undefined || quantity === null) {
            return res.status(400).json({ error: 'Quantity is required' });
        }

        const product = await prisma.product.findUnique({
            where: { id: parseInt(id, 10) },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const newQuantity = product.quantity + quantity;

        if (newQuantity < 0) {
            return res.status(400).json({ error: 'Adjustment would result in negative stock' });
        }

        const updatedProduct = await prisma.product.update({
            where: { id: parseInt(id, 10) },
            data: { quantity: newQuantity },
        });

        await prisma.movement.create({
            data: {
                productId: product.id,
                productName: product.name,
                userId: req.user!.id,
                username: req.user!.username,
                operationType: 'adjust',
                quantityChange: quantity,
                oldQuantity: product.quantity,
                newQuantity,
                details: details || null,
            },
        });

        res.json({
            ...updatedProduct,
            isLowStock: updatedProduct.quantity <= updatedProduct.minQuantity,
        });
    } catch (error) {
        console.error('Adjust stock error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// PATCH /api/products/:id/activate - Activate/Deactivate product (Admin only)
router.patch('/:id/activate', authenticateToken, requireAdmin, async (req: AuthRequest, res) => {
    try {
        const { id } = req.params;
        const { isActive } = req.body;

        if (isActive === undefined) {
            return res.status(400).json({ error: 'isActive is required' });
        }

        const product = await prisma.product.findUnique({
            where: { id: parseInt(id, 10) },
        });

        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const updatedProduct = await prisma.product.update({
            where: { id: parseInt(id, 10) },
            data: { isActive },
        });

        res.json(updatedProduct);
    } catch (error) {
        console.error('Activate product error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
