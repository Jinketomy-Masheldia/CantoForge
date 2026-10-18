// SPDX-License-Identifier: GPL-3.0-only
#include "logger.h"

#include <atomic>
#include <chrono>
#include <future>
#include <iostream>
#include <thread>

using namespace kors::logger;
using namespace std::chrono_literals;

class BlockingDest : public LogDest
{
public:
    BlockingDest() : LogDest(LogLayout("")) {}
    std::string name() const override { return "BlockingDest"; }
    void write(const LogMsg&) override
    {
        entered.set_value();
        release.get_future().wait();
    }
    std::promise<void> entered;
    std::promise<void> release;
};

class CountingDest : public LogDest
{
public:
    CountingDest(std::atomic<int>& count) : LogDest(LogLayout("")), m_count(count) {}
    std::string name() const override { return "CountingDest"; }
    void write(const LogMsg&) override { ++m_count; }
private:
    std::atomic<int>& m_count;
};

int main()
{
    auto logger = Logger::instance();
    logger->clearDests();
    const LogMsg message(Logger::INFO, "lifetime-probe", Color::None, "probe");

    // Removing an output must wait until its last virtual write has returned.
    auto blocked = new BlockingDest;
    auto entered = blocked->entered.get_future();
    logger->addDest(blocked);
    std::thread writer([&] { logger->write(message); });
    if (entered.wait_for(5s) != std::future_status::ready) {
        blocked->release.set_value();
        writer.join();
        logger->removeDest(blocked);
        delete blocked;
        std::cerr << "Writer did not enter the output\n";
        return 1;
    }
    std::promise<void> removing, removed;
    auto removeStarted = removing.get_future();
    auto removeFinished = removed.get_future();
    std::thread remover([&] {
        removing.set_value();
        logger->removeDest(blocked);
        removed.set_value();
    });
    removeStarted.wait();
    const bool returnedDuringWrite = removeFinished.wait_for(100ms) == std::future_status::ready;
    blocked->release.set_value();
    writer.join();
    remover.join();
    delete blocked;
    if (returnedDuringWrite) {
        std::cerr << "Output removed while its write was still active\n";
        return 2;
    }

    // Exercise registration, removal, destruction and clearing while audio-like
    // workers continue writing. Use the actual vendored logger implementation.
    std::atomic<bool> stop { false };
    std::atomic<int> count { 0 };
    auto loop = [&] {
        while (!stop.load()) {
            logger->write(message);
            std::this_thread::yield();
        }
    };
    std::thread worker1(loop), worker2(loop);
    for (int i = 0; i < 2000; ++i) {
        auto output = new CountingDest(count);
        logger->addDest(output);
        logger->write(message);
        logger->removeDest(output);
        delete output;
    }
    for (int i = 0; i < 500; ++i) {
        logger->addDest(new CountingDest(count));
        logger->write(message);
        logger->clearDests();
    }
    stop = true;
    worker1.join();
    worker2.join();
    logger->clearDests();
    if (!logger->dests().empty() || count < 2500) {
        std::cerr << "Logger output lifecycle failed\n";
        return 3;
    }
    std::cout << "Logger lifetime probe passed: removal waits for writes; concurrent add/remove/clear/write\n";
}
