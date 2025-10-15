const express = require('express');
const { PrismaClient } = require('@prisma/client');
const bodyParser = require('body-parser');
const cors = require('cors');
const PDFDocument = require('pdfkit');

const prisma = new PrismaClient();
const app = express();

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// -------------------- НАКЛАДНЫЕ PDF С ПОДДЕРЖКОЙ РУССКОГО ЯЗЫКА --------------------
app.get('/api/supplies/:id/invoice', async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log('🔧 Генерация PDF накладной для поставки:', id);
    
    const supply = await prisma.supply.findUnique({
      where: { id: parseInt(id) },
      include: {
        fromSupplier: true,
        toStore: true
      }
    });

    if (!supply) {
      return res.status(404).json({ error: 'Поставка не найдена' });
    }

    let orderData;
    try {
      orderData = JSON.parse(supply.content);
    } catch (e) {
      orderData = {
        batchName: 'Товар из поставки',
        description: supply.content,
        quantity: 1,
        itemsPerBatch: 1,
        totalPrice: 0,
        expiration: 30
      };
    }

    // Создаем PDF документ
    const doc = new PDFDocument({
      margins: {
        top: 50,
        bottom: 50,
        left: 50,
        right: 50
      }
    });
    
    // Устанавливаем заголовки
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="invoice-${supply.id}.pdf"`);
    
    // Пайпим ответ
    doc.pipe(res);

    // Используем встроенные шрифты PDF для поддержки кириллицы
    doc.font('fonts/arial.ttf');

    // Заголовок документа
    doc.fontSize(20)
       .text('НАКЛАДНАЯ', 50, 50, { align: 'center' });
    
    doc.fontSize(12)
       .text(`№ ${supply.id}-${Date.now()}`, 50, 80, { align: 'center' });
    
    const currentDate = new Date().toLocaleDateString('ru-RU');
    doc.text(`Дата: ${currentDate}`, 50, 100, { align: 'center' });
    
    doc.moveDown(2);

    // Информация о поставщике
    doc.fontSize(14)
       .text('ПОСТАВЩИК:', 50, 150);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Название: ${supply.fromSupplier.name}`, 50, 170);
    doc.text(`Адрес: ${supply.fromSupplier.address}`, 50, 185);
    doc.text(`Описание: ${supply.fromSupplier.description || 'Нет описания'}`, 50, 200);
    
    doc.moveDown(1);

    // Информация о получателе
    doc.fontSize(14)
       .text('ПОЛУЧАТЕЛЬ:', 50, 240);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Название: ${supply.toStore.name}`, 50, 260);
    doc.text(`Адрес: ${supply.toStore.address}`, 50, 275);
    doc.text(`Описание: ${supply.toStore.description || 'Нет описания'}`, 50, 290);
    
    doc.moveDown(1);

    // Информация о поставке
    doc.fontSize(14)
       .text('ИНФОРМАЦИЯ О ПОСТАВКЕ:', 50, 330);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Номер заказа: ${supply.id}`, 50, 350);
    doc.text(`Статус: ${supply.status}`, 50, 365);
    
    const createdDate = supply.createdAt ? new Date(supply.createdAt).toLocaleDateString('ru-RU') : 'Неизвестно';
    doc.text(`Дата заказа: ${createdDate}`, 50, 380);
    doc.text(`Дата получения: ${currentDate}`, 50, 395);
    
    doc.moveDown(1);

    // Товарная часть
    doc.fontSize(14)
       .text('ТОВАРНАЯ ИНФОРМАЦИЯ:', 50, 430);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Наименование товара: ${orderData.batchName || 'Товар из поставки'}`, 50, 450);
    doc.text(`Описание: ${orderData.description || 'Нет описания'}`, 50, 465);
    doc.text(`Количество партий: ${orderData.quantity || 1}`, 50, 480);
    doc.text(`Единиц в партии: ${orderData.itemsPerBatch || 1}`, 50, 495);
    doc.text(`Всего единиц: ${(orderData.quantity || 1) * (orderData.itemsPerBatch || 1)}`, 50, 510);
    doc.text(`Срок годности: ${orderData.expiration || 30} дней`, 50, 525);
    doc.text(`Общая стоимость: ${orderData.totalPrice || 0} руб.`, 50, 540);
    
    doc.moveDown(2);

    // Подписи
    const signatureY = 580;
    doc.fontSize(12)
       .text('ПОДПИСИ И ПЕЧАТИ:', 50, signatureY);
    
    doc.fontSize(10)
       .text('___________________', 50, signatureY + 20)
       .text('___________________', 300, signatureY + 20);
    
    doc.text(`${supply.fromSupplier.name}`, 50, signatureY + 35)
       .text(`${supply.toStore.name}`, 300, signatureY + 35);
    
    doc.text('(Поставщик)', 50, signatureY + 50)
       .text('(Получатель)', 300, signatureY + 50);

    // Разделительная линия
    doc.moveTo(50, signatureY + 70)
       .lineTo(550, signatureY + 70)
       .stroke();

    // Примечания
    doc.fontSize(10)
       .text('Примечания:', 50, signatureY + 85)
       .text('1. Товар получен в полном объеме и надлежащего качества.', 50, signatureY + 100)
       .text('2. Претензии по количеству и качеству товара не имеются.', 50, signatureY + 115);


    doc.end();

  } catch (error) {
    console.error('❌ Ошибка при генерации PDF накладной:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- МАГАЗИНЫ --------------------
app.get('/stores', async (req, res) => {
  try {
    const stores = await prisma.store.findMany({ 
      include: { 
        warehouse: true, 
        supplies: true,
        reviews: true 
      } 
    });
    res.json(stores);
  } catch (error) {
    console.error('Ошибка при получении магазинов:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/stores', async (req, res) => {
  try {
    const { name, password, address, description, photo } = req.body;
    
    if (!name || !password || !address) {
      return res.status(400).json({ error: 'Название, пароль и адрес обязательны' });
    }

    const store = await prisma.store.create({
      data: { 
        name, 
        password, 
        address, 
        description: description || '', 
        photo: photo || null,
        warehouse: {
          create: {
            productCount: 0
          }
        }
      },
      include: {
        warehouse: true
      }
    });

    res.json(store);
  } catch (error) {
    console.error('Ошибка при создании магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/stores/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, password, address, description, photo } = req.body;
    
    const updated = await prisma.store.update({
      where: { id: parseInt(id) },
      data: { 
        name, 
        password, 
        address, 
        description, 
        photo 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/stores/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.store.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- СКЛАДЫ --------------------
app.get('/warehouses', async (req, res) => {
  try {
    const warehouses = await prisma.warehouse.findMany({ 
      include: { 
        store: true, 
        products: {
          include: {
            product: true
          }
        }
      } 
    });
    res.json(warehouses);
  } catch (error) {
    console.error('Ошибка при получении складов:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// Получить склад магазина
app.get('/warehouses/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    
    console.log('🔧 Получение склада для магазина:', storeId);

    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      return res.status(400).json({ error: 'Неверный ID магазина' });
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { storeId: storeIdNum },
      include: { 
        products: {
          include: {
            product: true
          }
        },
        store: true
      }
    });

    if (!warehouse) {
      console.log('❌ Склад не найден для магазина:', storeId);
      return res.status(404).json({ error: 'Склад не найден' });
    }

    console.log('✅ Склад найден с товарами:', warehouse.products.length);
    res.json(warehouse);
  } catch (error) {
    console.error('❌ Ошибка при получении склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// Добавить товар на склад магазина
app.post('/warehouses/:storeId/products', async (req, res) => {
  try {
    const { storeId } = req.params;
    const { name, description, expiration, price, photo } = req.body;
    
    console.log('🔧 Добавление товара на склад магазина:', storeId);

    if (!name) {
      return res.status(400).json({ error: 'Название обязательно' });
    }

    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      return res.status(400).json({ error: 'Неверный ID магазина' });
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { storeId: storeIdNum }
    });

    console.log('🔧 Найден склад:', warehouse);

    if (!warehouse) {
      return res.status(404).json({ error: 'Склад не найден для этого магазина' });
    }

    const result = await prisma.$transaction(async (prisma) => {
      const product = await prisma.product.create({
        data: { 
          name, 
          description: description || '', 
          expiration: parseInt(expiration) || 30, 
          price: parseFloat(price) || 0, 
          photo: photo || null 
        },
      });

      console.log('✅ Создан товар:', product);

      const productOnWarehouse = await prisma.productOnWarehouse.create({
        data: {
          productId: product.id,
          warehouseId: warehouse.id,
        },
        include: {
          product: true,
          warehouse: true
        }
      });

      console.log('✅ Добавлен на склад:', productOnWarehouse);

      const updatedWarehouse = await prisma.warehouse.update({
        where: { id: warehouse.id },
        data: {
          productCount: {
            increment: 1
          }
        }
      });

      console.log('✅ Обновлено количество на складе:', updatedWarehouse.productCount);

      return product;
    });

    res.json(result);
  } catch (error) {
    console.error('❌ Ошибка при добавлении товара на склад:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.post('/warehouses', async (req, res) => {
  try {
    const { storeId, productCount } = req.body;
    
    if (!storeId) {
      return res.status(400).json({ error: 'storeId обязателен' });
    }

    const warehouse = await prisma.warehouse.create({
      data: { 
        storeId: parseInt(storeId), 
        productCount: productCount || 0 
      },
    });
    res.json(warehouse);
  } catch (error) {
    console.error('Ошибка при создании склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/warehouses/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { storeId, productCount } = req.body;
    
    const updated = await prisma.warehouse.update({
      where: { id: parseInt(id) },
      data: { 
        storeId: parseInt(storeId), 
        productCount 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/warehouses/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.warehouse.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ТОВАРЫ --------------------
app.get('/products', async (req, res) => {
  try {
    const products = await prisma.product.findMany({ 
      include: { 
        warehouses: {
          include: {
            warehouse: true
          }
        }
      } 
    });
    res.json(products);
  } catch (error) {
    console.error('Ошибка при получении товаров:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/products', async (req, res) => {
  try {
    const { name, description, expiration, price, photo } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Название обязательно' });
    }

    const product = await prisma.product.create({
      data: { 
        name, 
        description: description || '', 
        expiration: expiration || 0, 
        price: price || 0, 
        photo: photo || null 
      },
    });
    res.json(product);
  } catch (error) {
    console.error('Ошибка при создании товара:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, expiration, price, photo } = req.body;
    
    const updated = await prisma.product.update({
      where: { id: parseInt(id) },
      data: { 
        name, 
        description, 
        expiration, 
        price, 
        photo 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении товара:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.product.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении товара:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ПОСТАВЩИКИ --------------------
app.get('/suppliers', async (req, res) => {
  try {
    const suppliers = await prisma.supplier.findMany({ 
      include: { 
        batches: true, 
        supplies: true,
        reviews: true 
      } 
    });
    res.json(suppliers);
  } catch (error) {
    console.error('Ошибка при получении поставщиков:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/suppliers', async (req, res) => {
  try {
    const { name, password, address, description, batchCount, photo } = req.body;
    
    if (!name || !password || !address) {
      return res.status(400).json({ error: 'Название, пароль и адрес обязательны' });
    }

    const supplier = await prisma.supplier.create({
      data: { 
        name, 
        password, 
        address, 
        description: description || '', 
        photo: photo || null,
        batchCount: batchCount || 0
      },
    });
    res.json(supplier);
  } catch (error) {
    console.error('Ошибка при создании поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/suppliers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, password, address, description, batchCount, photo } = req.body;
    
    const updated = await prisma.supplier.update({
      where: { id: parseInt(id) },
      data: { 
        name, 
        password, 
        address, 
        description, 
        batchCount,
        photo 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/suppliers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.supplier.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ПАРТИИ ТОВАРОВ --------------------
app.get('/batches', async (req, res) => {
  try {
    const batches = await prisma.productBatch.findMany({ 
      include: { 
        supplier: true 
      } 
    });
    res.json(batches);
  } catch (error) {
    console.error('Ошибка при получении партий:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/batches', async (req, res) => {
  try {
    const { name, description, expiration, price, photo, productCount, supplierId } = req.body;
    
    if (!name || !supplierId) {
      return res.status(400).json({ error: 'Название и supplierId обязательны' });
    }

    const batch = await prisma.productBatch.create({
      data: { 
        name, 
        description: description || '', 
        expiration: expiration || 0, 
        price: price || 0, 
        photo: photo || null, 
        productCount: productCount || 1, 
        supplierId: parseInt(supplierId) 
      },
    });
    res.json(batch);
  } catch (error) {
    console.error('Ошибка при создании партии:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/batches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, expiration, price, photo, productCount, supplierId } = req.body;
    
    const updated = await prisma.productBatch.update({
      where: { id: parseInt(id) },
      data: { 
        name, 
        description, 
        expiration, 
        price, 
        photo, 
        productCount, 
        supplierId: parseInt(supplierId) 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении партии:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/batches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.productBatch.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении партии:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ПОСТАВКИ --------------------
app.get('/supplies', async (req, res) => {
  try {
    const supplies = await prisma.supply.findMany({ 
      include: { 
        fromSupplier: true, 
        toStore: true 
      } 
    });
    res.json(supplies);
  } catch (error) {
    console.error('Ошибка при получении поставок:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/supplies', async (req, res) => {
  try {
    const { fromSupplierId, toStoreId, content, status } = req.body;
    
    if (!fromSupplierId || !toStoreId) {
      return res.status(400).json({ error: 'fromSupplierId и toStoreId обязательны' });
    }

    const supply = await prisma.supply.create({
      data: { 
        fromSupplierId: parseInt(fromSupplierId), 
        toStoreId: parseInt(toStoreId), 
        content: content || '', 
        status: status || 'оформлен' 
      },
    });
    res.json(supply);
  } catch (error) {
    console.error('Ошибка при создании поставки:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/supplies/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { fromSupplierId, toStoreId, content, status } = req.body;
    
    const updated = await prisma.supply.update({
      where: { id: parseInt(id) },
      data: { 
        fromSupplierId: parseInt(fromSupplierId), 
        toStoreId: parseInt(toStoreId), 
        content, 
        status 
      },
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении поставки:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/supplies/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.supply.delete({ where: { id: parseInt(id) } });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении поставки:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ОТЗЫВЫ --------------------
app.get('/reviews', async (req, res) => {
  try {
    const reviews = await prisma.review.findMany({ 
      include: { 
        fromStore: true, 
        toSupplier: true 
      } 
    });
    res.json(reviews);
  } catch (error) {
    console.error('Ошибка при получении отзывов:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/reviews/supplier/:supplierId', async (req, res) => {
  try {
    const { supplierId } = req.params;
    const reviews = await prisma.review.findMany({
      where: { toSupplierId: parseInt(supplierId) },
      include: { fromStore: true }
    });
    res.json(reviews);
  } catch (error) {
    console.error('Ошибка при получении отзывов поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/reviews/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    const reviews = await prisma.review.findMany({
      where: { fromStoreId: parseInt(storeId) },
      include: { toSupplier: true }
    });
    res.json(reviews);
  } catch (error) {
    console.error('Ошибка при получении отзывов магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/reviews', async (req, res) => {
  try {
    const { fromStoreId, toSupplierId, text } = req.body;
    
    if (!fromStoreId || !toSupplierId || !text) {
      return res.status(400).json({ error: 'Все поля обязательны: fromStoreId, toSupplierId, text' });
    }

    const review = await prisma.review.create({
      data: { 
        fromStoreId: parseInt(fromStoreId), 
        toSupplierId: parseInt(toSupplierId), 
        text 
      },
      include: {
        fromStore: true,
        toSupplier: true
      }
    });
    res.json(review);
  } catch (error) {
    console.error('Ошибка при создании отзыва:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/reviews/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { text } = req.body;
    
    const updated = await prisma.review.update({
      where: { id: parseInt(id) },
      data: { text },
      include: {
        fromStore: true,
        toSupplier: true
      }
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка при обновлении отзыва:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/reviews/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.review.delete({ 
      where: { id: parseInt(id) } 
    });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении отзыва:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- СООБЩЕНИЯ ПОДДЕРЖКИ --------------------
app.get('/support-messages', async (req, res) => {
  try {
    const messages = await prisma.supportMessage.findMany({ 
      include: { 
        fromStore: true, 
        fromSupplier: true 
      } 
    });
    res.json(messages);
  } catch (error) {
    console.error('Ошибка при получении сообщений поддержки:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/support-messages/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    const messages = await prisma.supportMessage.findMany({
      where: { fromStoreId: parseInt(storeId) },
      include: { fromStore: true }
    });
    res.json(messages);
  } catch (error) {
    console.error('Ошибка при получении сообщений поддержки магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/support-messages/supplier/:supplierId', async (req, res) => {
  try {
    const { supplierId } = req.params;
    const messages = await prisma.supportMessage.findMany({
      where: { fromSupplierId: parseInt(supplierId) },
      include: { fromSupplier: true }
    });
    res.json(messages);
  } catch (error) {
    console.error('Ошибка при получении сообщений поддержки поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/support-messages/store', async (req, res) => {
  try {
    const { fromStoreId, text } = req.body;
    
    if (!fromStoreId || !text) {
      return res.status(400).json({ error: 'Все поля обязательны: fromStoreId, text' });
    }

    const message = await prisma.supportMessage.create({
      data: { 
        fromStoreId: parseInt(fromStoreId), 
        fromSupplierId: null,
        text 
      },
      include: {
        fromStore: true
      }
    });
    res.json(message);
  } catch (error) {
    console.error('Ошибка при создании сообщения поддержки магазина:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/support-messages/supplier', async (req, res) => {
  try {
    const { fromSupplierId, text } = req.body;
    
    if (!fromSupplierId || !text) {
      return res.status(400).json({ error: 'Все поля обязательны: fromSupplierId, text' });
    }

    const message = await prisma.supportMessage.create({
      data: { 
        fromStoreId: null,
        fromSupplierId: parseInt(fromSupplierId), 
        text 
      },
      include: {
        fromSupplier: true
      }
    });
    res.json(message);
  } catch (error) {
    console.error('Ошибка при создании сообщения поддержки поставщика:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/support-messages/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await prisma.supportMessage.delete({ 
      where: { id: parseInt(id) } 
    });
    res.json(deleted);
  } catch (error) {
    console.error('Ошибка при удалении сообщения поддержки:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- УПРАВЛЕНИЕ ТОВАРАМИ НА СКЛАДЕ --------------------

// Удалить товар со склада (продать)
app.delete('/warehouse-products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const productOnWarehouse = await prisma.productOnWarehouse.findUnique({
      where: { id: parseInt(id) },
      include: {
        warehouse: true
      }
    });

    if (!productOnWarehouse) {
      return res.status(404).json({ error: 'Товар на складе не найден' });
    }

    await prisma.productOnWarehouse.delete({
      where: { id: parseInt(id) }
    });

    const updatedWarehouse = await prisma.warehouse.update({
      where: { id: productOnWarehouse.warehouseId },
      data: {
        productCount: {
          decrement: 1
        }
      }
    });

    res.json({ 
      message: 'Товар удален со склада',
      warehouse: updatedWarehouse 
    });
  } catch (error) {
    console.error('Ошибка при удалении товара со склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// Массовое удаление товаров со склада
app.post('/warehouse-products/bulk-delete', async (req, res) => {
  try {
    const { warehouseIds } = req.body;
    
    if (!warehouseIds || !Array.isArray(warehouseIds)) {
      return res.status(400).json({ error: 'Массив warehouseIds обязателен' });
    }

    const productsOnWarehouse = await prisma.productOnWarehouse.findMany({
      where: {
        id: {
          in: warehouseIds.map(id => parseInt(id))
        }
      },
      include: {
        warehouse: true
      }
    });

    if (productsOnWarehouse.length === 0) {
      return res.status(404).json({ error: 'Товары не найдены' });
    }

    const warehouseGroups = {};
    productsOnWarehouse.forEach(item => {
      const warehouseId = item.warehouseId;
      if (!warehouseGroups[warehouseId]) {
        warehouseGroups[warehouseId] = {
          count: 0,
          warehouse: item.warehouse
        };
      }
      warehouseGroups[warehouseId].count++;
    });

    await prisma.productOnWarehouse.deleteMany({
      where: {
        id: {
          in: warehouseIds.map(id => parseInt(id))
        }
      }
    });

    for (const [warehouseId, group] of Object.entries(warehouseGroups)) {
      await prisma.warehouse.update({
        where: { id: parseInt(warehouseId) },
        data: {
          productCount: {
            decrement: group.count
          }
        }
      });
    }

    res.json({ 
      message: `Успешно удалено ${productsOnWarehouse.length} товаров со склада`,
      removedCount: productsOnWarehouse.length
    });
  } catch (error) {
    console.error('Ошибка при массовом удалении товаров со склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// Получить товары на складе магазина с группировкой
app.get('/warehouses/store/:storeId/products-grouped', async (req, res) => {
  try {
    const { storeId } = req.params;
    
    console.log('🔧 Получение сгруппированных товаров для магазина:', storeId);

    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      return res.status(400).json({ error: 'Неверный ID магазина' });
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { storeId: storeIdNum },
      include: { 
        products: {
          include: {
            product: true
          }
        }
      }
    });

    if (!warehouse) {
      console.log('❌ Склад не найден для магазина:', storeId);
      return res.status(404).json({ error: 'Склад не найден' });
    }

    console.log('✅ Склад найден с товарами:', warehouse.products.length);

    const groupedProducts = {};
    
    warehouse.products.forEach(productOnWarehouse => {
      const product = productOnWarehouse.product;
      const key = `${product.name}_${product.description}_${product.expiration}_${product.price}_${product.photo || ''}`;
      
      if (groupedProducts[key]) {
        groupedProducts[key].count += 1;
        groupedProducts[key].warehouseIds.push(productOnWarehouse.id);
      } else {
        groupedProducts[key] = {
          product: product,
          count: 1,
          warehouseIds: [productOnWarehouse.id],
          firstWarehouseId: productOnWarehouse.id
        };
      }
    });

    const result = {
      warehouse: warehouse,
      groupedProducts: Object.values(groupedProducts)
    };

    console.log('📦 Результат сгруппированных товаров:', result.groupedProducts.length);
    res.json(result);
  } catch (error) {
    console.error('❌ Ошибка при получении сгруппированных товаров склада:', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- СЕРВЕР --------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Сервер запущен на http://localhost:${PORT}`);
});