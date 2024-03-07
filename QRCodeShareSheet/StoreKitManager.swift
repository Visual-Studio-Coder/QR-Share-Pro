//
//  StoreKitManager.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import Foundation
import StoreKit

public enum StoreError: Error {
    case failedVerification
}

class StoreKitManager: ObservableObject {
    @Published var storeProducts: [Product] = []
    @Published var purchasedPlan: [Product] = []
    
    var updateListenerTask: Task<Void, Error>? = nil
    
    private let productDict: [String: String]
    
    init() {
        // check the path for the plist
        if let plistPath = Bundle.main.path(forResource: "QRShareProList", ofType: "plist"),
           // get the list of products
           let plist = FileManager.default.contents(atPath: plistPath) {
            productDict = (try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String : String]) ?? [:]
        } else {
            productDict = [:]
        }
        
        // Start a transaction listener as close to the app launch as possible so you don't miss any transaction
        updateListenerTask = listenForTransactions()
        
        // create async operation
        Task {
            await requestProducts()
            
            // deliver the products that the customer purchased
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // listen for transactions - start this early in the app
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // iterate through any transactions that don't come from a direct call to 'purchase()'
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // the transaction is verified, deliver the content to the user
                    await self.updateCustomerProductStatus()
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    // storekit has a transaction that fails verification, don't delvier content to the user
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    // request the products in the background
    @MainActor
    func requestProducts() async {
        do {
            // using the Product static method products to retrieve the list of products
            storeProducts = try await Product.products(for: productDict.values)
            
            // iterate the "type" if there are multiple product types.
        } catch {
            print("Failed - error retrieving products \(error)")
        }
    }
    
    // Generics - check the verificationResults
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // check if JWS passes the StoreKit verification
        switch result {
        case .unverified:
            // failed verificaiton
            throw StoreError.failedVerification
        case .verified(let signedType):
            // the result is verified, return the unwrapped value
            return signedType
        }
    }
    
    // update the customers products
    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedPlan: [Product] = []
        
        // iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                // again check if transaction is verified
                let transaction = try checkVerified(result)
                // since we only have one type of producttype - .nonconsumables -- check if any storeProducts matches the transaction.productID then add to the purchasedCourses
                if let plan = storeProducts.first(where: { $0.id == transaction.productID}) {
                    purchasedPlan.append(plan)
                }
                
            } catch {
                // storekit has a transaction that fails verification, don't delvier content to the user
                print("Transaction failed verification")
            }
            
            // finally assign the purchased products
            self.purchasedPlan = purchasedPlan
        }
    }
    
    // call the product purchase and returns an optional transaction
    func purchase(_ product: Product) async throws -> Transaction? {
        //make a purchase request - optional parameters available
        let result = try await product.purchase()
        
        // check the results
        switch result {
        case .success(let verificationResult):
            // Transaction will be verified for automatically using JWT(jwsRepresentation) - we can check the result
            let transaction = try checkVerified(verificationResult)
            
            // the transaction is verified, deliver the content to the user
            await updateCustomerProductStatus()
            
            // always finish a transaction - performance
            await transaction.finish()
            
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
        
    }
    
    // check if product has already been purchased
    func isPurchased(_ product: Product) async throws -> Bool {
        // as we only have one product type grouping .nonconsumable - we check if it belongs to the purchasedPlan which ran init()
        return purchasedPlan.contains(product)
    }
}
