package com.example.orderservice.services;

import com.example.orderservice.model.Order;
import com.example.orderservice.repository.OrderRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Random;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final Random random = new Random();

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    public Order createOrder(Order order) {
        order.setId(generateRandomOrderId());
        order.setOrderDate(LocalDateTime.now());

        return orderRepository.save(order);
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    public Optional<Order> getOrderById(String id) {
        return orderRepository.findById(id);
    }

    public Optional<Order> updateOrder(String id, Order updatedOrder) {
        Optional<Order> existingOrder = orderRepository.findById(id);

        if (existingOrder.isPresent()) {
            Order order = existingOrder.get();

            order.setCustomerName(updatedOrder.getCustomerName());
            order.setProduct(updatedOrder.getProduct());
            order.setQuantity(updatedOrder.getQuantity());
            order.setPrice(updatedOrder.getPrice());

            Order savedOrder = orderRepository.save(order);

            return Optional.of(savedOrder);
        }

        return Optional.empty();
    }

    public boolean deleteOrder(String id) {
        Optional<Order> existingOrder = orderRepository.findById(id);

        if (existingOrder.isPresent()) {
            orderRepository.delete(existingOrder.get());
            return true;
        }

        return false;
    }

    private String generateRandomOrderId() {
        char letter = (char) ('A' + random.nextInt(26));
        int number = 1000 + random.nextInt(9000);

        return letter + String.valueOf(number);
    }
}
