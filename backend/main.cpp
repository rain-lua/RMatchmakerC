#include "include/httplib.h"
#include "include/json.hpp"

#include <openssl/hmac.h>
#include <openssl/evp.h>
#include <uuid/uuid.h>

#include <deque>
#include <unordered_map>
#include <unordered_set>
#include <mutex>
#include <thread>
#include <chrono>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <ctime>

using json = nlohmann::json;

constexpr int MATCH_SIZE = 1;
constexpr int REQUEST_TTL_SECONDS = 30;
constexpr int TICKET_TTL_SECONDS = 1800;

const std::string SECRET_HEX = "1c8832532dbf515f674a658fb1b2492d5a879100c0550c984fbe383ec8c7212c0490cf3d3f585b0e43c78398f91bb47fe08b5dc137ce7a753e8589aadbd11e66b321ff108a802489e883ed8c916abe9cd6b26d546eb8be653a079015aacbe88f275229cf5ee54ec06154a059d30b05069365bdbcc32f10fafdf06a59475f58a59b8c9bfd9cae72650ea975683fbf155146f7748b597d98161a64abbd6dbb1edc0ec72aa6ab072c5fc2a15acadef66c1aa527d1dec6ff77c2363d5a0beb52d8f098cacfd4737979563cf5910d7e8bddc2488c3fed8f2c3a6bf7c883abef4e441fcce8cee5b574f2af4570fa7a9d63674f88b997cc301ad8d143271a14e6255108";

std::string hexToBytes(const std::string& hex) {
    std::string bytes;
    bytes.reserve(hex.size() / 2);
    for (size_t i = 0; i < hex.size(); i += 2) {
        unsigned int byte;
        std::stringstream ss;
        ss << std::hex << hex.substr(i, 2);
        ss >> byte;
        bytes.push_back(static_cast<char>(byte));
    }
    return bytes;
}

const std::string SECRET = hexToBytes(SECRET_HEX);

struct Player {
    std::string userId;
    std::string ticket;
    int elo;
    std::string Region;
    time_t queuedAt;
};

struct Match {
    std::string matchId;
    std::vector<Player> players;
};

std::unordered_map<std::string, std::deque<Player>> regionQueues;  
std::unordered_map<std::string, Match> matches;
std::unordered_map<std::string, std::string> ticketOwner;  
std::unordered_map<std::string, std::string> ticketRegion; 
std::unordered_set<std::string> queuedUsers;
std::mutex mtx;

const std::vector<std::string> REGIONS = {"EU", "NA", "OCE", "ME"};

std::string generateUUID(const std::string& prefix) {
    uuid_t u;
    uuid_generate(u);
    char s[37];
    uuid_unparse(u, s);
    return prefix + s;
}

std::string hmac_sha256(const std::string& key, const std::string& data) {
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int len;

    HMAC(EVP_sha256(),
         reinterpret_cast<const unsigned char*>(key.data()), key.size(),
         reinterpret_cast<const unsigned char*>(data.data()), data.size(),
         hash, &len);

    std::ostringstream oss;
    for (unsigned i = 0; i < len; ++i)
        oss << std::hex << std::setw(2) << std::setfill('0')
            << static_cast<int>(hash[i]);
    return oss.str();
}

bool constantTimeEquals(const std::string& a, const std::string& b) {
    if (a.size() != b.size()) return false;
    unsigned char result = 0;
    for (size_t i = 0; i < a.size(); ++i)
        result |= a[i] ^ b[i];
    return result == 0;
}

bool verifyRequest(const httplib::Request& req) {
    if (!req.has_header("X-Timestamp") || !req.has_header("X-Signature")) return false;

    const auto& ts = req.get_header_value("X-Timestamp");
    const auto& sig = req.get_header_value("X-Signature");

    long timestamp;
    try { timestamp = std::stol(ts); } catch (...) { return false; }

    if (std::abs(time(nullptr) - timestamp) > REQUEST_TTL_SECONDS) return false;

    std::string canonical = ts + req.body;

    std::string expected = hmac_sha256(SECRET, canonical);

    return constantTimeEquals(expected, sig);
}

void matchmakingLoop() {
    while (true) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        std::lock_guard<std::mutex> lock(mtx);

        time_t now = time(nullptr);

        for (const auto& region : REGIONS) {
            auto& queue = regionQueues[region];
            
            while (queue.size() >= MATCH_SIZE) {
                Match match;
                match.matchId = generateUUID("match_");

                for (int i = 0; i < MATCH_SIZE; ++i) {
                    Player p = queue.front();
                    queue.pop_front();
                    queuedUsers.erase(p.userId);

                    match.players.push_back(p);
                }

                matches[match.matchId] = match;
            }

            queue.erase(
                std::remove_if(queue.begin(), queue.end(),
                    [&](const Player& p) {
                        if (now - p.queuedAt > TICKET_TTL_SECONDS) {
                            queuedUsers.erase(p.userId);
                            ticketOwner.erase(p.ticket);
                            ticketRegion.erase(p.ticket);
                            return true;
                        }
                        return false;
                    }),
                queue.end()
            );
        }
    }
}

int main() {
    httplib::Server svr;

    svr.Post("/queue", [](const httplib::Request& req, httplib::Response& res) {
        if (!verifyRequest(req)) {
            res.status = 401;
            return;
        }

        std::cout << "Verified request.\n";

        json j;
        try { j = json::parse(req.body); } catch (...) { res.status = 400; return; }

        std::string userId = std::to_string(j["pid"].get<long long>());
        int elo = j.value("elo", 1000);
        std::string region = j.value("region", "EU"); 

        bool validRegion = false;
        for (const auto& r : REGIONS) {
            if (r == region) {
                validRegion = true;
                break;
            }
        }
        if (!validRegion) {
            region = "EU"; 
        }

        std::lock_guard<std::mutex> lock(mtx);

        if (queuedUsers.find(userId) != queuedUsers.end()) { res.status = 409; return; }

        Player p;
        p.userId = userId;
        p.elo = elo;
        p.Region = region;
        p.ticket = generateUUID("ticket_");
        p.queuedAt = time(nullptr);

        regionQueues[region].push_back(p);
        queuedUsers.insert(userId);
        ticketOwner[p.ticket] = p.userId;
        ticketRegion[p.ticket] = region;

        std::cout << "Queued player " << userId << " in region " << region << " with ticket " << p.ticket << "\n";

        res.set_content(json{{"ticketId", p.ticket}}.dump(), "application/json");
    });

    svr.Get(R"(/match/(.+))", [](const httplib::Request& req, httplib::Response& res) {
        if (!verifyRequest(req)) { res.status = 401; return; }

        std::string ticket = req.matches[1];

        std::lock_guard<std::mutex> lock(mtx);

        auto ownerIt = ticketOwner.find(ticket);
        if (ownerIt == ticketOwner.end()) { res.status = 404; return; }

        for (auto it = matches.begin(); it != matches.end(); ++it) {
            for (auto& p : it->second.players) {
                if (p.ticket == ticket) {
                    json out;
                    out["matchId"] = it->second.matchId;
                    for (auto& pl : it->second.players)
                        out["players"].push_back(pl.userId);

                    res.set_content(out.dump(), "application/json");

                    for (auto& pl : it->second.players)
                        ticketOwner.erase(pl.ticket);

                    std::cout << "Match found for ticket " << ticket << ": "
                              << it->second.matchId << "\n";

                    matches.erase(it);
                    return;
                }
            }
        }

        res.status = 404;
    });

    svr.Delete(R"(/queue/(.+))", [](const httplib::Request& req, httplib::Response& res) {
        if (!verifyRequest(req)) { res.status = 401; return; }

        std::string ticket = req.matches[1];

        std::lock_guard<std::mutex> lock(mtx);
        
        auto ownerIt = ticketOwner.find(ticket);
        if (ownerIt == ticketOwner.end()) { res.status = 404; return; }

        std::string userId = ownerIt->second;
        std::string region = ticketRegion[ticket];

        auto& queue = regionQueues[region];
        queue.erase(
            std::remove_if(queue.begin(), queue.end(),
                [&](const Player& p) {
                    return p.ticket == ticket;
                }),
            queue.end()
        );

        queuedUsers.erase(userId);
        ticketOwner.erase(ticket);
        ticketRegion.erase(ticket);

        std::cout << "Cancelled queue for ticket " << ticket << " in region " << region << "\n";
        res.set_content("Queue cancelled", "text/plain");
    });

    std::thread(matchmakingLoop).detach();
    std::cout << "Matchmaker running on port 3000\n";
    svr.listen("0.0.0.0", 3000);
}