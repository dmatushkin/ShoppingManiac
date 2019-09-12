//
//  DAO.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/6/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import RxSwift
import RxCocoa

extension NSManagedObject {
    
    class func className() -> String {
        return String(describing: self)
    }
}

extension NSManagedObjectContext {
    
    func edit<T: NSManagedObject>(_ object: T?) -> T? {
        guard let object = object else { return nil }
        return self.object(with: object.objectID) as? T
    }
    
    func edit<T: NSManagedObject>(_ objectId: NSManagedObjectID?) -> T? {
        guard let objectId = objectId else { return nil }
        return self.object(with: objectId) as? T
    }
    
    func fetchAll<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil, sort: [NSSortDescriptor]? = nil) -> [T] {
        let request: NSFetchRequest<T> = NSFetchRequest(entityName: T.className())
        request.predicate = predicate
        request.sortDescriptors = sort
        do {
            return try self.fetch(request)
        } catch {
            return []
        }
    }
    
    func fetchOne<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil, sort: [NSSortDescriptor]? = nil, index: Int? = nil) -> T? {
        let request: NSFetchRequest<T> = NSFetchRequest(entityName: T.className())
        request.predicate = predicate
        request.sortDescriptors = sort
        if let index = index {
            request.fetchOffset = index
        }
        request.fetchLimit = 1
        do {
            return try self.fetch(request).first
        } catch {
            return nil
        }
    }
    
    func fetchCount<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil) -> Int {
        let request: NSFetchRequest<T> = NSFetchRequest(entityName: T.className())
        request.predicate = predicate
        do {
            return try self.count(for: request)
        } catch {
            return 0
        }
    }
    
    func create<T: NSManagedObject>() -> T {
        //swiftlint:disable force_cast
        return NSEntityDescription.insertNewObject(forEntityName: T.className(), into: self) as! T
    }
}

class DAO {
    
    private init() {
    }
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentCloudKitContainer(name: "ShoppingManiac")
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    class func saveChanges() {
        try? shared.persistentContainer.viewContext.save()
    }
    
    private static let shared = DAO()
    
    class func performAsync<T>(updates: @escaping ((NSManagedObjectContext) -> T)) -> Observable<T> {
        let subject = PublishSubject<T>()
        let context = shared.persistentContainer.newBackgroundContext()
        context.perform {
            let result = updates(context)
            do {
                try context.save()
                subject.onNext(result)
            } catch {
                subject.onError(error)
            }
        }
        return subject.asObservable()
    }
    
    class func performSync<T>(updates: (NSManagedObjectContext) -> T) -> T? {
        let context = shared.persistentContainer.viewContext
        var result: T?
        context.performAndWait {
            result = updates(context)
            try? context.save()
        }
        return result
    }
    
    class func fetchAll<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil, sort: [NSSortDescriptor]? = nil) -> [T] {
        return shared.persistentContainer.viewContext.fetchAll(from, predicate: predicate, sort: sort)
    }
    
    class func fetchOne<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil, sort: [NSSortDescriptor]? = nil, index: Int? = nil) -> T? {
        return shared.persistentContainer.viewContext.fetchOne(from, predicate: predicate, sort: sort, index: index)
    }
    
    class func fetchExisting<T: NSManagedObject>(_ object: T?) -> T? {
        guard let object = object else { return nil }
        return shared.persistentContainer.viewContext.object(with: object.objectID) as? T
    }
    
    class func fetchExisting<T: NSManagedObject>(_ objectId: NSManagedObjectID) -> T? {
        return shared.persistentContainer.viewContext.object(with: objectId) as? T
    }
    
    class func fetchCount<T: NSManagedObject>(_ from: T.Type, predicate: NSPredicate? = nil) -> Int {
        return shared.persistentContainer.viewContext.fetchCount(from, predicate: predicate)
    }
}
