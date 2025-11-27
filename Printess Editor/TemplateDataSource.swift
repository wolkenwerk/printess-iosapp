//
//  TemplateDataSource.swift
//  Printess Editor
//
//  Created by Tobias Klonk on 29.12.21.
//  Copyright © 2021 Printess GmbH & Co. KG. All rights reserved.
//

import Foundation

struct TemplateResponse: Codable {
  var uid: String
  var email: String
  var templates: [Template]

  enum CodingKeys: String, CodingKey {
    case uid
    case email = "e"
    case templates = "ts"
  }
}

struct Template: Codable {
  var id: Int
  var name: String
  var thumbnailURL: String?
  var backgroundColor: String
  var w: Bool
  var p: Bool
  var d: Bool
  var hpv: Bool
  var hdv: Bool
  var ls: String
  var lp: String

  enum CodingKeys: String, CodingKey {
    case id
    case name = "n"
    case thumbnailURL = "turl"
    case backgroundColor = "bg"
    case w
    case p
    case d
    case hpv
    case hdv
    case ls
    case lp
  }
}

struct LoadingError: Error {
  enum ErrorKind {
    case networkError
    case httpError
    case internalError
    case parsingError
  }

  let title: String
  let details: String
  let underlyingError: Error?
  let kind: ErrorKind
}


class TemplateDataSource {

  let bearerToken = """
  eyJhbGciOiJSUzI1NiIsImtpZCI6InByaW50ZXNzLXNhYXMtYWxwaGEiLCJ0eXAiOiJKV1QifQ.eyJzdWIiOiJneTh6NDRFbUxpWjB2clV\
  LclhsV3RpWlkxNUQyIiwianRpIjoibnl4NGJFZlZ5SVVvM1NkR2dYVnEtempzS3hlb0FYZUYiLCJyb2xlIjoic2hvcCIsIm5iZiI6MTYxO\
  Dg2ODUxMSwiZXhwIjoxOTM0MjI4NTExLCJpYXQiOjE2MTg4Njg1MTEsImlzcyI6IlByaW50ZXNzIEdtYkggJiBDby5LRyIsImF1ZCI6InB\
  yaW50ZXNzLXNhYXMifQ.CuI6zdCzBm2y3t2GBD4pYdyztFzSeSEfdGIDBeiZIYvzQckB9oEB1Z4hDkBCGZGBtTMRyuHCbkwZgO6uxD-Zya\
  hifiqrIqfqSqtFEGwgZUF87TvV_KlrYWBzDNTaUIQjr-yUoxLkdnEMzh-3D5qV8UKWIDfqwnYd0KhJiB2K9CSg82_etnz5Lk-altMDAT8b\
  1AnzxcjRAJ9_b6-CAJFXG6AAnfdl7c_PS3sD-RPOkJ75Ta2glfikIiGZzfh09bn5Ptk7rucRdxUsLCLR6m5nUFpZbV77d2eqRw8pT4Kl-5\
  by5gvMr1wUBGbEx751CNXtcCO3qk4uNnptfZ3yCpK0Z2FOo2CYLZBzmDiYCrdFV5U-_SZuVOEl8vk0uR3tj_PQci_R7MlQOjpB4NjlKckQ\
  2zGvBSKNeupuiC71UZ2AT5BFlbqMsuYu0necIztyKiWsBmbniVlLe-v7_paP1N4nS2haD2n4s4N_CenJqijtPggWsITfoLm2twCOe7yNB5\
  IH7bcEFv1-MbANuaFmJVLOcTfc89Zi-mkidaHV-n_9qXypzyB-ih_27YBNluRGwcHgTEkbJecSssMfvHSt1MUuqX-8gbl7bhFGryqHA2gM\
  oSZNDW0LkSYig2K3poOUumD67vtYdNSPLhOmDK4ck9wLAKLOvk6dtywg2qfV-58_VbI
  """

  func loadTemplatesList(completion: @escaping (Result<[Template], LoadingError>) -> Void) {
    guard let url = URL.init(string: "https://api.printess.com/templates/global/load") else { return }

    var request = URLRequest.init(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in

      guard error == nil else {
        DispatchQueue.main.async {
          completion(.failure(LoadingError(title: "Network Error",
                                           details: error!.localizedDescription,
                                           underlyingError: error,
                                           kind: .networkError)))
        }
        return
      }

      if let response = response as? HTTPURLResponse {
        if response.statusCode < 200 || response.statusCode >= 400 {
          DispatchQueue.main.async {
            completion(.failure(LoadingError(title: "HTTP Error \(response.statusCode)",
                                             details: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                                             underlyingError: nil,
                                             kind: .httpError)))
          }
          return
        }
      }

      guard let responseData = data else {
        DispatchQueue.main.async {
          completion(.failure(LoadingError(title: "Internal Error",
                                           details: "Empty response",
                                           underlyingError: nil,
                                           kind: .internalError)))
        }
        return
      }

      let decoder = JSONDecoder()
      do {
        let response = try decoder.decode(TemplateResponse.self, from: responseData)

        DispatchQueue.main.async {
          completion(.success(response.templates))
        }

      } catch {
        DispatchQueue.main.async {
          completion(.failure(LoadingError(title: "Parsing Error",
                                           details: error.localizedDescription,
                                           underlyingError: error,
                                           kind: .parsingError)))
        }
      }
    }

    dataTask.resume()
  }
}


