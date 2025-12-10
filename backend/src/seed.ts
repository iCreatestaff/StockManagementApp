import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
    console.log('Seeding database...');

    // Create admin user
    const adminPassword = await bcrypt.hash('admin123', 10);
    const admin = await prisma.user.upsert({
        where: { username: 'admin' },
        update: {},
        create: {
            username: 'admin',
            passwordHash: adminPassword,
            role: 'admin',
        },
    });
    console.log('Created admin user:', admin.username);

    // Create normal user
    const userPassword = await bcrypt.hash('user123', 10);
    const user = await prisma.user.upsert({
        where: { username: 'user' },
        update: {},
        create: {
            username: 'user',
            passwordHash: userPassword,
            role: 'user',
        },
    });
    console.log('Created normal user:', user.username);

    // Create sample products
    const products = [
        { name: 'Widget A', sku: 'WGT-001', quantity: 100, unit: 'pcs', minQuantity: 20, category: 'Widgets' },
        { name: 'Widget B', sku: 'WGT-002', quantity: 50, unit: 'pcs', minQuantity: 10, category: 'Widgets' },
        { name: 'Gadget X', sku: 'GDT-001', quantity: 15, unit: 'pcs', minQuantity: 25, category: 'Gadgets' },
        { name: 'Cable USB-C', sku: 'CBL-001', quantity: 200, unit: 'pcs', minQuantity: 50, category: 'Cables' },
        { name: 'Power Supply', sku: 'PWR-001', quantity: 30, unit: 'pcs', minQuantity: 10, category: 'Electronics' },
    ];

    for (const p of products) {
        const product = await prisma.product.upsert({
            where: { sku: p.sku },
            update: {},
            create: p,
        });
        console.log('Created product:', product.name);
    }

    console.log('Seeding completed!');
    console.log('');
    console.log('Default credentials:');
    console.log('  Admin: admin / admin123');
    console.log('  User:  user / user123');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
