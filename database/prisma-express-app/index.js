const express = require('express');
const { PrismaClient } = require('@prisma/client');
const bodyParser = require('body-parser');
const cors = require('cors');
const PDFDocument = require('pdfkit');
const REQUIRED_APP_VERSION = "1.2.0";

const prisma = new PrismaClient();
const app = express();

// Вспомогательная функция для форматирования срока годности
const formatExpiration = (expiration) => {
  if (!expiration || expiration <= 0) {
    return null; // или '' для пустой строки
  }
  return expiration;
};

// Настройка логирования
const logger = {
  info: (message, data = {}) => {
    console.log(`📘 INFO [${new Date().toISOString()}]: ${message}`, Object.keys(data).length ? data : '');
  },
  warn: (message, data = {}) => {
    console.warn(`⚠️ WARN [${new Date().toISOString()}]: ${message}`, Object.keys(data).length ? data : '');
  },
  error: (message, data = {}) => {
    console.error(`❌ ERROR [${new Date().toISOString()}]: ${message}`, Object.keys(data).length ? data : '');
  },
  success: (message, data = {}) => {
    console.log(`✅ SUCCESS [${new Date().toISOString()}]: ${message}`, Object.keys(data).length ? data : '');
  },
  request: (req) => {
    logger.info(`[${req.method}] ${req.originalUrl}`, {
      ip: req.ip,
      userAgent: req.headers['user-agent'],
      body: req.method !== 'GET' ? req.body : undefined,
      params: req.params,
      query: req.query
    });
  }
};

// Middleware для логирования запросов
app.use((req, res, next) => {
  logger.request(req);
  next();
});

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Middleware для проверки версии приложения
const checkAppVersion = (req, res, next) => {
  const clientVersion = req.headers['x-app-version'];
  
  logger.info('Проверка версии приложения', { clientVersion, requiredVersion: REQUIRED_APP_VERSION });
  
  // Если версия не совпадает точно - блокируем запрос
  if (clientVersion !== REQUIRED_APP_VERSION) {
    logger.warn('Несовместимая версия приложения', { clientVersion, requiredVersion: REQUIRED_APP_VERSION });
    return res.status(426).json({ 
      error: 'Требуется обновление приложения',
      requiredVersion: REQUIRED_APP_VERSION,
      currentVersion: clientVersion 
    });
  }
  
  logger.success('Версия приложения проверена успешно');
  next();
};

// -------------------- АУТЕНТИФИКАЦИЯ --------------------

// Вход магазина
app.post('/stores/login', checkAppVersion, async (req, res) => {
  try {
    const { name, password } = req.body;
    logger.info('Вход магазина', { name });
    
    if (!name || !password) {
      logger.warn('Не указаны обязательные поля для входа магазина');
      return res.status(400).json({ error: 'Название и пароль обязательны' });
    }

    const store = await prisma.store.findFirst({
      where: { 
        name,
        password 
      },
      include: {
        warehouse: true
      }
    });

    if (!store) {
      logger.warn('Неверные учетные данные магазина', { name });
      return res.status(401).json({ error: 'Неверные учетные данные' });
    }

    logger.success('Успешный вход магазина', { storeId: store.id, name: store.name });
    res.json(store);
  } catch (error) {
    logger.error('Ошибка при входе магазина', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// Вход поставщика
app.post('/suppliers/login', checkAppVersion, async (req, res) => {
  try {
    const { name, password } = req.body;
    logger.info('Вход поставщика', { name });
    
    if (!name || !password) {
      logger.warn('Не указаны обязательные поля для входа поставщика');
      return res.status(400).json({ error: 'Название и пароль обязательны' });
    }

    const supplier = await prisma.supplier.findFirst({
      where: { 
        name,
        password 
      }
    });

    if (!supplier) {
      logger.warn('Неверные учетные данные поставщика', { name });
      return res.status(401).json({ error: 'Неверные учетные данные' });
    }

    logger.success('Успешный вход поставщика', { supplierId: supplier.id, name: supplier.name });
    res.json(supplier);
  } catch (error) {
    logger.error('Ошибка при входе поставщика', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- НАКЛАДНЫЕ PDF --------------------
app.get('/api/supplies/:id/invoice', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Генерация PDF накладной', { supplyId: id });
    
    const supply = await prisma.supply.findUnique({
      where: { id: parseInt(id) },
      include: {
        fromSupplier: true,
        toStore: true
      }
    });

    if (!supply) {
      logger.warn('Поставка не найдена для генерации PDF', { supplyId: id });
      return res.status(404).json({ error: 'Поставка не найдена' });
    }

    let orderData;
    try {
      orderData = JSON.parse(supply.content);
    } catch (e) {
      logger.warn('Не удалось распарсить контент поставки, используем значения по умолчанию', { supplyId: id });
      orderData = {
        batchName: 'Товар из поставки',
        description: supply.content,
        quantity: 1,
        itemsPerBatch: 1,
        totalPrice: 0,
        expiration: 30
      };
    }

    const doc = new PDFDocument({
      margins: {
        top: 50,
        bottom: 50,
        left: 50,
        right: 50
      }
    });
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="invoice-${supply.id}.pdf"`);
    
    doc.pipe(res);

    // Генерация PDF...
    doc.font('fonts/arial.ttf');

    doc.fontSize(20)
       .text('НАКЛАДНАЯ', 50, 50, { align: 'center' });
    
    doc.fontSize(12)
       .text(`№ ${supply.id}-${Date.now()}`, 50, 80, { align: 'center' });
    
    const currentDate = new Date().toLocaleDateString('ru-RU');
    doc.text(`Дата: ${currentDate}`, 50, 100, { align: 'center' });
    
    doc.moveDown(2);

    doc.fontSize(14)
       .text('ПОСТАВЩИК:', 50, 150);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Название: ${supply.fromSupplier.name}`, 50, 170);
    doc.text(`Адрес: ${supply.fromSupplier.address}`, 50, 185);
    doc.text(`Описание: ${supply.fromSupplier.description || 'Нет описания'}`, 50, 200);
    
    doc.moveDown(1);

    doc.fontSize(14)
       .text('ПОЛУЧАТЕЛЬ:', 50, 240);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Название: ${supply.toStore.name}`, 50, 260);
    doc.text(`Адрес: ${supply.toStore.address}`, 50, 275);
    doc.text(`Описание: ${supply.toStore.description || 'Нет описания'}`, 50, 290);
    
    doc.moveDown(1);

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

    doc.fontSize(14)
       .text('ТОВАРНАЯ ИНФОРМАЦИЯ:', 50, 430);
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .text(`Наименование товара: ${orderData.batchName || 'Товар из поставки'}`, 50, 450);
    doc.text(`Описание: ${orderData.description || 'Нет описания'}`, 50, 465);
    doc.text(`Количество партий: ${orderData.quantity || 1}`, 50, 480);
    doc.text(`Единиц в партии: ${orderData.itemsPerBatch || 1}`, 50, 495);
    doc.text(`Всего единиц: ${(orderData.quantity || 1) * (orderData.itemsPerBatch || 1)}`, 50, 510);
if (orderData.expiration && orderData.expiration > 0) {
  doc.text(`Срок годности: ${orderData.expiration} дней`, 50, 525);
}    doc.text(`Общая стоимость: ${orderData.totalPrice || 0} руб.`, 50, 540);
    
    doc.moveDown(2);

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

    doc.moveTo(50, signatureY + 70)
       .lineTo(550, signatureY + 70)
       .stroke();

    doc.fontSize(10)
       .text('Примечания:', 50, signatureY + 85)
       .text('1. Товар получен в полном объеме и надлежащего качества.', 50, signatureY + 100)
       .text('2. Претензии по количеству и качеству товара не имеются.', 50, signatureY + 115);

    doc.end();
    
    logger.success('PDF накладная успешно сгенерирована', { supplyId: id });

  } catch (error) {
    logger.error('Ошибка при генерации PDF накладной', { error: error.message, supplyId: req.params.id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- МАГАЗИНЫ --------------------
app.get('/stores', async (req, res) => {
  try {
    logger.info('Получение списка магазинов');
    const stores = await prisma.store.findMany({ 
      include: { 
        warehouse: true, 
        supplies: true,
        reviews: true 
      } 
    });
    logger.success('Магазины успешно получены', { count: stores.length });
    res.json(stores);
  } catch (error) {
    logger.error('Ошибка при получении магазинов', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/stores', async (req, res) => {
  try {
    const { name, password, address, description, photo } = req.body;
    logger.info('Создание нового магазина', { name, address });
    
    if (!name || !password || !address) {
      logger.warn('Не указаны обязательные поля для создания магазина');
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

    logger.success('Магазин успешно создан', { storeId: store.id, name: store.name });
    res.json(store);
  } catch (error) {
    logger.error('Ошибка при создании магазина', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/stores/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, password, address, description, photo } = req.body;
    logger.info('Обновление магазина', { storeId: id });
    
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
    
    logger.success('Магазин успешно обновлен', { storeId: id, name: updated.name });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении магазина', { error: error.message, storeId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/stores/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const storeId = parseInt(id);
    logger.info('Удаление магазина', { storeId });
    
    const store = await prisma.store.findUnique({
      where: { id: storeId }
    });

    if (!store) {
      logger.warn('Магазин не найден при попытке удаления', { storeId });
      return res.status(404).json({ error: 'Магазин не найден' });
    }

    const result = await prisma.$transaction(async (tx) => {
      const warehouse = await tx.warehouse.findFirst({
        where: { storeId: storeId }
      });

      if (warehouse) {
        await tx.productOnWarehouse.deleteMany({
          where: { warehouseId: warehouse.id }
        });
        
        await tx.warehouse.delete({
          where: { id: warehouse.id }
        });
      }

      await tx.review.deleteMany({
        where: { fromStoreId: storeId }
      });

      await tx.supportMessage.deleteMany({
        where: { fromStoreId: storeId }
      });

      await tx.supply.deleteMany({
        where: { toStoreId: storeId }
      });

      const deletedStore = await tx.store.delete({
        where: { id: storeId }
      });

      return deletedStore;
    });

    logger.success('Магазин успешно удален', { storeId, name: store.name });
    res.json({ message: 'Магазин и все связанные данные успешно удалены', deletedStore: result });
    
  } catch (error) {
    logger.error('Ошибка при удалении магазина', { error: error.message, storeId: req.params.id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- СКЛАДЫ --------------------
app.get('/warehouses', async (req, res) => {
  try {
    logger.info('Получение списка складов');
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
    logger.success('Склады успешно получены', { count: warehouses.length });
    res.json(warehouses);
  } catch (error) {
    logger.error('Ошибка при получении складов', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/warehouses/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    logger.info('Получение склада магазина', { storeId });
    
    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      logger.warn('Неверный ID магазина', { storeId });
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
      logger.warn('Склад не найден для магазина', { storeId });
      return res.status(404).json({ error: 'Склад не найден' });
    }

    logger.success('Склад найден', { storeId, productCount: warehouse.products.length });
    res.json(warehouse);
  } catch (error) {
    logger.error('Ошибка при получении склада', { error: error.message, storeId: req.params.storeId });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.post('/warehouses/:storeId/products', async (req, res) => {
  try {
    const { storeId } = req.params;
    const { name, description, expiration, price, photo } = req.body;
    logger.info('Добавление товара на склад', { storeId, name });
    
    if (!name) {
      logger.warn('Не указано название товара');
      return res.status(400).json({ error: 'Название обязательно' });
    }

    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      logger.warn('Неверный ID магазина', { storeId });
      return res.status(400).json({ error: 'Неверный ID магазина' });
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { storeId: storeIdNum }
    });

    if (!warehouse) {
      logger.warn('Склад не найден для магазина', { storeId });
      return res.status(404).json({ error: 'Склад не найден для этого магазина' });
    }

    const result = await prisma.$transaction(async (prisma) => {
      const product = await prisma.product.create({
        data: { 
          name, 
          description: description || '', 
          // Изменение здесь: принимаем 0 или null как отсутствие срока
          expiration: expiration && parseInt(expiration) > 0 ? parseInt(expiration) : 0, 
          price: parseFloat(price) || 0, 
          photo: photo || null 
        },
      });

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

      const updatedWarehouse = await prisma.warehouse.update({
        where: { id: warehouse.id },
        data: {
          productCount: {
            increment: 1
          }
        }
      });

      return product;
    });

    logger.success('Товар успешно добавлен на склад', { 
      storeId, 
      productId: result.id, 
      name: result.name 
    });
    res.json(result);
  } catch (error) {
    logger.error('Ошибка при добавлении товара на склад', { 
      error: error.message, 
      storeId: req.params.storeId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.post('/warehouses', async (req, res) => {
  try {
    const { storeId, productCount } = req.body;
    logger.info('Создание склада', { storeId });
    
    if (!storeId) {
      logger.warn('Не указан storeId для создания склада');
      return res.status(400).json({ error: 'storeId обязателен' });
    }

    const warehouse = await prisma.warehouse.create({
      data: { 
        storeId: parseInt(storeId), 
        productCount: productCount || 0 
      },
    });
    
    logger.success('Склад успешно создан', { warehouseId: warehouse.id, storeId });
    res.json(warehouse);
  } catch (error) {
    logger.error('Ошибка при создании склада', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/warehouses/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { storeId, productCount } = req.body;
    logger.info('Обновление склада', { warehouseId: id });
    
    const updated = await prisma.warehouse.update({
      where: { id: parseInt(id) },
      data: { 
        storeId: parseInt(storeId), 
        productCount 
      },
    });
    
    logger.success('Склад успешно обновлен', { warehouseId: id });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении склада', { error: error.message, warehouseId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/warehouses/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление склада', { warehouseId: id });
    
    const deleted = await prisma.warehouse.delete({ where: { id: parseInt(id) } });
    
    logger.success('Склад успешно удален', { warehouseId: id });
    res.json(deleted);
  } catch (error) {
    logger.error('Ошибка при удалении склада', { error: error.message, warehouseId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ТОВАРЫ --------------------
app.get('/products', async (req, res) => {
  try {
    logger.info('Получение списка товаров');
    const products = await prisma.product.findMany({ 
      include: { 
        warehouses: {
          include: {
            warehouse: true
          }
        }
      } 
    });
    logger.success('Товары успешно получены', { count: products.length });
    res.json(products);
  } catch (error) {
    logger.error('Ошибка при получении товаров', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/products', async (req, res) => {
  try {
    const { name, description, expiration, price, photo } = req.body;
    logger.info('Создание товара', { name });
    
    if (!name) {
      logger.warn('Не указано название товара');
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
    
    logger.success('Товар успешно создан', { productId: product.id, name: product.name });
    res.json(product);
  } catch (error) {
    logger.error('Ошибка при создании товара', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, expiration, price, photo } = req.body;
    logger.info('Обновление товара', { productId: id });
    
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
    
    logger.success('Товар успешно обновлен', { productId: id, name: updated.name });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении товара', { error: error.message, productId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление товара', { productId: id });
    
    const deleted = await prisma.product.delete({ where: { id: parseInt(id) } });
    
    logger.success('Товар успешно удален', { productId: id, name: deleted.name });
    res.json(deleted);
  } catch (error) {
    logger.error('Ошибка при удалении товара', { error: error.message, productId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ПОСТАВЩИКИ --------------------
app.get('/suppliers', async (req, res) => {
  try {
    logger.info('Получение списка поставщиков');
    const suppliers = await prisma.supplier.findMany({ 
      include: { 
        batches: true, 
        supplies: true,
        reviews: true 
      } 
    });
    logger.success('Поставщики успешно получены', { count: suppliers.length });
    res.json(suppliers);
  } catch (error) {
    logger.error('Ошибка при получении поставщиков', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/suppliers', async (req, res) => {
  try {
    const { name, password, address, description, photo } = req.body;
    logger.info('Создание нового поставщика', { name, address });
    
    if (!name || !password || !address) {
      logger.warn('Не указаны обязательные поля для создания поставщика');
      return res.status(400).json({ error: 'Название, пароль и адрес обязательны' });
    }

    const supplier = await prisma.supplier.create({
      data: { 
        name, 
        password, 
        address, 
        description: description || '', 
        photo: photo || null,
      },
    });
    
    logger.success('Поставщик успешно создан', { supplierId: supplier.id, name: supplier.name });
    res.json(supplier);
  } catch (error) {
    logger.error('Ошибка при создании поставщика', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/suppliers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, password, address, description, batchCount, photo } = req.body;
    logger.info('Обновление поставщика', { supplierId: id });
    
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
    
    logger.success('Поставщик успешно обновлен', { supplierId: id, name: updated.name });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении поставщика', { error: error.message, supplierId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/suppliers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const supplierId = parseInt(id);
    logger.info('Удаление поставщика', { supplierId });
    
    await prisma.$transaction(async (prisma) => {
      await prisma.productBatch.deleteMany({
        where: { supplierId: supplierId }
      });

      await prisma.review.deleteMany({
        where: { toSupplierId: supplierId }
      });

      await prisma.supportMessage.deleteMany({
        where: { fromSupplierId: supplierId }
      });

      await prisma.supply.deleteMany({
        where: { fromSupplierId: supplierId }
      });

      await prisma.supplier.delete({
        where: { id: supplierId }
      });
    });

    logger.success('Поставщик успешно удален', { supplierId });
    res.json({ message: 'Поставщик и все связанные данные успешно удалены' });
  } catch (error) {
    logger.error('Ошибка при удалении поставщика', { error: error.message, supplierId: req.params.id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- ПАРТИИ ТОВАРОВ --------------------
app.get('/batches', async (req, res) => {
  try {
    logger.info('Получение списка партий товаров');
    const batches = await prisma.batch.findMany({ 
      include: { 
        supplier: true 
      } 
    });
    logger.success('Партии товаров успешно получены', { count: batches.length });
    
    // Возвращаем в формате, ожидаемом клиентом
    const formattedBatches = batches.map(batch => ({
      ...batch,
      // Для совместимости со старым кодом
      productCount: batch.quantity * batch.itemsPerBatch,
      id: batch.id,
      name: batch.name,
      description: batch.description,
      expiration: batch.expiration,
      price: batch.price,
      photo: batch.photo,
      itemsPerBatch: batch.itemsPerBatch,
      quantity: batch.quantity,
      supplierId: batch.supplierId,
      supplier: batch.supplier,
      createdAt: batch.createdAt,
      updatedAt: batch.updatedAt
    }));
    
    res.json(formattedBatches);
  } catch (error) {
    logger.error('Ошибка при получении партий', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/batches', async (req, res) => {
  try {
    const { 
      name, 
      description, 
      expiration, 
      price, 
      photo, 
      itemsPerBatch, 
      quantity, 
      supplierId 
    } = req.body;
    
    logger.info('Создание партии товаров', { 
      name, 
      supplierId, 
      quantity, 
      itemsPerBatch 
    });
    
    if (!name || !supplierId) {
      logger.warn('Не указаны обязательные поля для создания партии');
      return res.status(400).json({ error: 'Название и supplierId обязательны' });
    }

    const batch = await prisma.batch.create({
      data: { 
        name, 
        description: description || '', 
        // Изменение здесь: принимаем 0 или null как отсутствие срока
        expiration: expiration && parseInt(expiration) > 0 ? parseInt(expiration) : 0, 
        price: price || 0, 
        photo: photo || null, 
        itemsPerBatch: parseInt(itemsPerBatch) || 1,
        quantity: parseInt(quantity) || 1,
        supplierId: parseInt(supplierId) 
      },
      include: {
        supplier: true
      }
    });
    
    logger.success('Партия товаров успешно создана', { 
      batchId: batch.id, 
      name: batch.name, 
      supplierId: batch.supplierId,
      quantity: batch.quantity,
      itemsPerBatch: batch.itemsPerBatch
    });
    
    res.json({
      ...batch,
      productCount: batch.quantity * batch.itemsPerBatch
    });
  } catch (error) {
    logger.error('Ошибка при создании партии', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.put('/batches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      name, 
      description, 
      expiration, 
      price, 
      photo, 
      itemsPerBatch, 
      quantity, 
      supplierId 
    } = req.body;
    
    logger.info('Обновление партии товаров', { batchId: id });
    
    const updated = await prisma.batch.update({
      where: { id: parseInt(id) },
      data: { 
        name, 
        description, 
        expiration, 
        price, 
        photo, 
        itemsPerBatch: parseInt(itemsPerBatch) || 1,
        quantity: parseInt(quantity) || 1,
        supplierId: parseInt(supplierId) 
      },
      include: {
        supplier: true
      }
    });
    
    logger.success('Партия товаров успешно обновлена', { 
      batchId: id, 
      name: updated.name,
      quantity: updated.quantity,
      itemsPerBatch: updated.itemsPerBatch
    });
    
    // Возвращаем в формате, ожидаемом клиентом
    res.json({
      ...updated,
      productCount: updated.quantity * updated.itemsPerBatch
    });
  } catch (error) {
    logger.error('Ошибка при обновлении партии', { 
      error: error.message, 
      batchId: id 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.delete('/batches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление партии товаров', { batchId: id });
    
    const deleted = await prisma.batch.delete({ 
      where: { id: parseInt(id) },
      include: {
        supplier: true
      }
    });
    
    logger.success('Партия товаров успешно удалена', { 
      batchId: id, 
      name: deleted.name 
    });
    
    // Возвращаем в формате, ожидаемом клиентом
    res.json({
      ...deleted,
      productCount: deleted.quantity * deleted.itemsPerBatch
    });
  } catch (error) {
    logger.error('Ошибка при удалении партии', { 
      error: error.message, 
      batchId: id 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- ПОСТАВКИ --------------------
app.get('/supplies', async (req, res) => {
  try {
    logger.info('Получение списка поставок');
    const supplies = await prisma.supply.findMany({ 
      include: { 
        fromSupplier: true, 
        toStore: true 
      } 
    });
    logger.success('Поставки успешно получены', { count: supplies.length });
    res.json(supplies);
  } catch (error) {
    logger.error('Ошибка при получении поставок', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/supplies', async (req, res) => {
  try {
    const { fromSupplierId, toStoreId, content, status } = req.body;
    logger.info('Создание поставки', { fromSupplierId, toStoreId });
    
    if (!fromSupplierId || !toStoreId) {
      logger.warn('Не указаны обязательные поля для создания поставки');
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
    
    logger.success('Поставка успешно создана', { 
      supplyId: supply.id, 
      fromSupplierId, 
      toStoreId 
    });
    res.json(supply);
  } catch (error) {
    logger.error('Ошибка при создании поставки', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/supplies/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { fromSupplierId, toStoreId, content, status } = req.body;
    logger.info('Обновление поставки', { supplyId: id });
    
    const updated = await prisma.supply.update({
      where: { id: parseInt(id) },
      data: { 
        fromSupplierId: parseInt(fromSupplierId), 
        toStoreId: parseInt(toStoreId), 
        content, 
        status 
      },
    });
    
    logger.success('Поставка успешно обновлена', { supplyId: id });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении поставки', { error: error.message, supplyId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/supplies/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление поставки', { supplyId: id });
    
    const deleted = await prisma.supply.delete({ where: { id: parseInt(id) } });
    
    logger.success('Поставка успешно удалена', { supplyId: id });
    res.json(deleted);
  } catch (error) {
    logger.error('Ошибка при удалении поставки', { error: error.message, supplyId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- ОТЗЫВЫ --------------------
app.get('/reviews', async (req, res) => {
  try {
    logger.info('Получение списка отзывов');
    const reviews = await prisma.review.findMany({ 
      include: { 
        fromStore: true, 
        toSupplier: true 
      } 
    });
    logger.success('Отзывы успешно получены', { count: reviews.length });
    res.json(reviews);
  } catch (error) {
    logger.error('Ошибка при получении отзывов', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/reviews/supplier/:supplierId', async (req, res) => {
  try {
    const { supplierId } = req.params;
    logger.info('Получение отзывов поставщика', { supplierId });
    
    const reviews = await prisma.review.findMany({
      where: { toSupplierId: parseInt(supplierId) },
      include: { fromStore: true }
    });
    
    logger.success('Отзывы поставщика получены', { supplierId, count: reviews.length });
    res.json(reviews);
  } catch (error) {
    logger.error('Ошибка при получении отзывов поставщика', { 
      error: error.message, 
      supplierId: req.params.supplierId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/reviews/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    logger.info('Получение отзывов магазина', { storeId });
    
    const reviews = await prisma.review.findMany({
      where: { fromStoreId: parseInt(storeId) },
      include: { toSupplier: true }
    });
    
    logger.success('Отзывы магазина получены', { storeId, count: reviews.length });
    res.json(reviews);
  } catch (error) {
    logger.error('Ошибка при получении отзывов магазина', { 
      error: error.message, 
      storeId: req.params.storeId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/reviews', async (req, res) => {
  try {
    const { fromStoreId, toSupplierId, text } = req.body;
    logger.info('Создание отзыва', { fromStoreId, toSupplierId });
    
    if (!fromStoreId || !toSupplierId || !text) {
      logger.warn('Не указаны обязательные поля для создания отзыва');
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
    
    logger.success('Отзыв успешно создан', { 
      reviewId: review.id, 
      fromStoreId, 
      toSupplierId 
    });
    res.json(review);
  } catch (error) {
    logger.error('Ошибка при создании отзыва', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.put('/reviews/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { text } = req.body;
    logger.info('Обновление отзыва', { reviewId: id });
    
    const updated = await prisma.review.update({
      where: { id: parseInt(id) },
      data: { text },
      include: {
        fromStore: true,
        toSupplier: true
      }
    });
    
    logger.success('Отзыв успешно обновлен', { reviewId: id });
    res.json(updated);
  } catch (error) {
    logger.error('Ошибка при обновлении отзыва', { error: error.message, reviewId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/reviews/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление отзыва', { reviewId: id });
    
    const deleted = await prisma.review.delete({ 
      where: { id: parseInt(id) } 
    });
    
    logger.success('Отзыв успешно удален', { reviewId: id });
    res.json(deleted);
  } catch (error) {
    logger.error('Ошибка при удалении отзыва', { error: error.message, reviewId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- СООБЩЕНИЯ ПОДДЕРЖКИ --------------------
app.get('/support-messages', async (req, res) => {
  try {
    logger.info('Получение списка сообщений поддержки');
    const messages = await prisma.supportMessage.findMany({ 
      include: { 
        fromStore: true, 
        fromSupplier: true 
      } 
    });
    logger.success('Сообщения поддержки успешно получены', { count: messages.length });
    res.json(messages);
  } catch (error) {
    logger.error('Ошибка при получении сообщений поддержки', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/support-messages/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    logger.info('Получение сообщений поддержки магазина', { storeId });
    
    const messages = await prisma.supportMessage.findMany({
      where: { fromStoreId: parseInt(storeId) },
      include: { fromStore: true }
    });
    
    logger.success('Сообщения поддержки магазина получены', { storeId, count: messages.length });
    res.json(messages);
  } catch (error) {
    logger.error('Ошибка при получении сообщений поддержки магазина', { 
      error: error.message, 
      storeId: req.params.storeId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/support-messages/supplier/:supplierId', async (req, res) => {
  try {
    const { supplierId } = req.params;
    logger.info('Получение сообщений поддержки поставщика', { supplierId });
    
    const messages = await prisma.supportMessage.findMany({
      where: { fromSupplierId: parseInt(supplierId) },
      include: { fromSupplier: true }
    });
    
    logger.success('Сообщения поддержки поставщика получены', { supplierId, count: messages.length });
    res.json(messages);
  } catch (error) {
    logger.error('Ошибка при получении сообщений поддержки поставщика', { 
      error: error.message, 
      supplierId: req.params.supplierId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/support-messages/store', async (req, res) => {
  try {
    const { fromStoreId, text } = req.body;
    logger.info('Создание сообщения поддержки от магазина', { fromStoreId });
    
    if (!fromStoreId || !text) {
      logger.warn('Не указаны обязательные поля для сообщения поддержки магазина');
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
    
    logger.success('Сообщение поддержки магазина создано', { 
      messageId: message.id, 
      fromStoreId 
    });
    res.json(message);
  } catch (error) {
    logger.error('Ошибка при создании сообщения поддержки магазина', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/support-messages/supplier', async (req, res) => {
  try {
    const { fromSupplierId, text } = req.body;
    logger.info('Создание сообщения поддержки от поставщика', { fromSupplierId });
    
    if (!fromSupplierId || !text) {
      logger.warn('Не указаны обязательные поля для сообщения поддержки поставщика');
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
    
    logger.success('Сообщение поддержки поставщика создано', { 
      messageId: message.id, 
      fromSupplierId 
    });
    res.json(message);
  } catch (error) {
    logger.error('Ошибка при создании сообщения поддержки поставщика', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.delete('/support-messages/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление сообщения поддержки', { messageId: id });
    
    const deleted = await prisma.supportMessage.delete({ 
      where: { id: parseInt(id) } 
    });
    
    logger.success('Сообщение поддержки успешно удалено', { messageId: id });
    res.json(deleted);
  } catch (error) {
    logger.error('Ошибка при удалении сообщения поддержки', { error: error.message, messageId: id });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

// -------------------- УПРАВЛЕНИЕ ТОВАРАМИ НА СКЛАДЕ --------------------
app.delete('/warehouse-products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Удаление товара со склада', { warehouseProductId: id });
    
    const productOnWarehouse = await prisma.productOnWarehouse.findUnique({
      where: { id: parseInt(id) },
      include: {
        warehouse: true
      }
    });

    if (!productOnWarehouse) {
      logger.warn('Товар на складе не найден', { warehouseProductId: id });
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

    logger.success('Товар удален со склада', { 
      warehouseProductId: id, 
      warehouseId: productOnWarehouse.warehouseId,
      productId: productOnWarehouse.productId 
    });
    
    res.json({ 
      message: 'Товар удален со склада',
      warehouse: updatedWarehouse 
    });
  } catch (error) {
    logger.error('Ошибка при удалении товара со склада', { 
      error: error.message, 
      warehouseProductId: id 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.post('/warehouse-products/bulk-delete', async (req, res) => {
  try {
    const { warehouseIds } = req.body;
    logger.info('Массовое удаление товаров со склада', { count: warehouseIds?.length || 0 });
    
    if (!warehouseIds || !Array.isArray(warehouseIds)) {
      logger.warn('Не указан массив warehouseIds для массового удаления');
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
      logger.warn('Товары не найдены для массового удаления');
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

    logger.success('Массовое удаление товаров выполнено', { 
      removedCount: productsOnWarehouse.length,
      affectedWarehouses: Object.keys(warehouseGroups).length 
    });
    
    res.json({ 
      message: `Успешно удалено ${productsOnWarehouse.length} товаров со склада`,
      removedCount: productsOnWarehouse.length
    });
  } catch (error) {
    logger.error('Ошибка при массовом удалении товаров со склада', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
});

app.get('/warehouses/store/:storeId/products-grouped', async (req, res) => {
  try {
    const { storeId } = req.params;
    logger.info('Получение сгруппированных товаров склада', { storeId });
    
    const storeIdNum = parseInt(storeId);
    if (isNaN(storeIdNum)) {
      logger.warn('Неверный ID магазина', { storeId });
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
      logger.warn('Склад не найден для магазина', { storeId });
      return res.status(404).json({ error: 'Склад не найден' });
    }

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

    logger.success('Сгруппированные товары получены', { 
      storeId, 
      productCount: warehouse.products.length,
      groupedCount: result.groupedProducts.length 
    });
    
    res.json(result);
  } catch (error) {
    logger.error('Ошибка при получении сгруппированных товаров склада', { 
      error: error.message, 
      storeId: req.params.storeId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- ЛОГИКА ПРОДАЖИ ТОВАРОВ --------------------
app.post('/orders/create', async (req, res) => {
  try {
    const { batchId, storeId, supplierId, quantity } = req.body;
    logger.info('Создание заказа', { batchId, storeId, supplierId, quantity });
    
    if (!batchId || !storeId || !supplierId || !quantity) {
      logger.warn('Не указаны обязательные поля для создания заказа');
      return res.status(400).json({ 
        error: 'Все поля обязательны: batchId, storeId, supplierId, quantity' 
      });
    }

    const batch = await prisma.batch.findFirst({
      where: { 
        id: parseInt(batchId),
        supplierId: parseInt(supplierId)
      },
      include: {
        supplier: true
      }
    });

    if (!batch) {
      logger.warn('Партия не найдена у поставщика', { batchId, supplierId });
      return res.status(404).json({ error: 'Партия не найдена у данного поставщика' });
    }

    // Проверяем доступное количество партий
    if (batch.quantity < quantity) {
      logger.warn('Недостаточно партий у поставщика', { 
        batchId, 
        available: batch.quantity, 
        requested: quantity 
      });
      return res.status(400).json({ 
        error: 'Недостаточно партий у поставщика',
        available: batch.quantity,
        requested: quantity
      });
    }

    const supply = await prisma.supply.create({
      data: { 
        fromSupplierId: parseInt(supplierId), 
        toStoreId: parseInt(storeId), 
        content: JSON.stringify({
          batchId: batch.id,
          batchName: batch.name,
          description: batch.description,
          expiration: batch.expiration,
          quantity: quantity,
          itemsPerBatch: batch.itemsPerBatch,
          totalItems: quantity * batch.itemsPerBatch,
          totalPrice: batch.price * quantity,
          supplierPhoto: batch.photo,
          supplierName: batch.supplier.name
        }), 
        status: 'оформлен' 
      },
      include: {
        fromSupplier: true,
        toStore: true
      }
    });

    logger.success('Заказ успешно создан', { 
      supplyId: supply.id, 
      batchId, 
      storeId, 
      supplierId 
    });
    
    res.json({ 
      message: 'Заказ успешно создан',
      supply: supply
    });
  } catch (error) {
    logger.error('Ошибка при создании заказа', { error: error.message });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.post('/orders/send', async (req, res) => {
  try {
    const { supplyId } = req.body;
    logger.info('Отправка заказа', { supplyId });
    
    if (!supplyId) {
      logger.warn('Не указан supplyId для отправки заказа');
      return res.status(400).json({ error: 'supplyId обязателен' });
    }

    const supply = await prisma.supply.findUnique({
      where: { id: parseInt(supplyId) },
      include: {
        fromSupplier: true
      }
    });

    if (!supply) {
      logger.warn('Поставка не найдена', { supplyId });
      return res.status(404).json({ error: 'Поставка не найдена' });
    }

    if (supply.status !== 'оформлен') {
      logger.warn('Неверный статус поставки для отправки', { 
        supplyId, 
        currentStatus: supply.status, 
        requiredStatus: 'оформлен' 
      });
      return res.status(400).json({ 
        error: 'Неверный статус поставки',
        currentStatus: supply.status,
        requiredStatus: 'оформлен'
      });
    }

    let orderData;
    try {
      orderData = JSON.parse(supply.content);
    } catch (e) {
      logger.warn('Неверный формат данных заказа', { supplyId });
      return res.status(400).json({ error: 'Неверный формат данных заказа' });
    }

    const batch = await prisma.batch.findFirst({
      where: { 
        id: orderData.batchId,
        supplierId: supply.fromSupplierId
      },
      include: {
        supplier: true
      }
    });

    if (!batch) {
      logger.warn('Партия не найдена', { batchId: orderData.batchId });
      return res.status(404).json({ error: 'Партия не найдена' });
    }

    // Проверяем доступное количество партий
    if (batch.quantity < orderData.quantity) {
      logger.warn('Недостаточно партий у поставщика для отправки', { 
        batchId: orderData.batchId, 
        available: batch.quantity, 
        required: orderData.quantity 
      });
      return res.status(400).json({ 
        error: 'Недостаточно партий у поставщика для отправки',
        available: batch.quantity,
        required: orderData.quantity
      });
    }

    // Уменьшаем количество партий
    const updatedBatch = await prisma.batch.update({
      where: { id: batch.id },
      data: {
        quantity: batch.quantity - orderData.quantity
      },
      include: {
        supplier: true
      }
    });

    const updatedSupply = await prisma.supply.update({
      where: { id: parseInt(supplyId) },
      data: { 
        status: 'отправлен',
        deliveryTime: new Date() // Устанавливаем время отправки
      },
      include: {
        fromSupplier: true,
        toStore: true
      }
    });

    logger.success('Заказ успешно отправлен', { 
      supplyId, 
      batchId: batch.id, 
      quantitySent: orderData.quantity,
      totalItems: orderData.quantity * batch.itemsPerBatch
    });
    
    res.json({ 
      message: 'Заказ успешно отправлен',
      supply: updatedSupply,
      updatedBatch: {
        ...updatedBatch,
        productCount: updatedBatch.quantity * updatedBatch.itemsPerBatch
      }
    });
  } catch (error) {
    logger.error('Ошибка при отправке заказа', { 
      error: error.message, 
      supplyId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

app.post('/orders/receive', async (req, res) => {
  try {
    const { supplyId, pricePerItem, photo } = req.body;
    logger.info('Получение заказа', { supplyId, pricePerItem });
    
    if (!supplyId || !pricePerItem) {
      logger.warn('Не указаны обязательные поля для получения заказа');
      return res.status(400).json({ error: 'supplyId и pricePerItem обязательны' });
    }

    const supply = await prisma.supply.findUnique({
      where: { id: parseInt(supplyId) },
      include: {
        toStore: true
      }
    });

    if (!supply) {
      logger.warn('Поставка не найдена', { supplyId });
      return res.status(404).json({ error: 'Поставка не найдена' });
    }

    if (supply.status !== 'отправлен') {
      logger.warn('Неверный статус поставки для получения', { 
        supplyId, 
        currentStatus: supply.status, 
        requiredStatus: 'отправлен' 
      });
      return res.status(400).json({ 
        error: 'Неверный статус поставки',
        currentStatus: supply.status,
        requiredStatus: 'отправлен'
      });
    }

    let orderData;
    try {
      orderData = JSON.parse(supply.content);
    } catch (e) {
      logger.warn('Неверный формат данных заказа', { supplyId });
      return res.status(400).json({ error: 'Неверный формат данных заказа' });
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { storeId: supply.toStoreId }
    });

    if (!warehouse) {
      logger.warn('Склад магазина не найден', { storeId: supply.toStoreId });
      return res.status(404).json({ error: 'Склад магазина не найден' });
    }

    const totalItems = orderData.quantity * orderData.itemsPerBatch;
    const createdProducts = [];

    for (let i = 0; i < totalItems; i++) {
      const product = await prisma.product.create({
        data: { 
          name: orderData.batchName || 'Товар из поставки',
          description: orderData.description || 'Товар получен из заказа',
          expiration: orderData.expiration || 30,
          price: parseFloat(pricePerItem),
          photo: photo || orderData.supplierPhoto || null
        }
      });

      await prisma.productOnWarehouse.create({
        data: {
          productId: product.id,
          warehouseId: warehouse.id
        }
      });

      createdProducts.push(product);
    }

    const updatedWarehouse = await prisma.warehouse.update({
      where: { id: warehouse.id },
      data: {
        productCount: {
          increment: totalItems
        }
      }
    });

    const updatedSupply = await prisma.supply.update({
      where: { id: parseInt(supplyId) },
      data: { 
        status: 'получено',
        deliveryTime: new Date() // Устанавливаем время получения
      }
    });

    logger.success('Заказ успешно получен', { 
      supplyId, 
      totalItems, 
      storeId: supply.toStoreId 
    });
    
    res.json({ 
      message: `Заказ получен, создано ${totalItems} товаров на складе`,
      createdCount: totalItems,
      supply: updatedSupply,
      warehouse: updatedWarehouse,
      products: createdProducts
    });
  } catch (error) {
    logger.error('Ошибка при получении заказа', { 
      error: error.message, 
      supplyId 
    });
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// -------------------- СЕРВЕР --------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.success(`🚀 Сервер запущен на порту ${PORT}, версия приложения: ${REQUIRED_APP_VERSION}`);
});